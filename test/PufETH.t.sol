// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {PufETH, IStETH, IStETHVault, IPufETHVault, IEigenLayer} from "../src/PufETH.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";

interface ITestStETH is IStETH {
    function mintFor(address who, uint256 _sharesAmount) external;
}

contract StETH is ERC20, ITestStETH {
    constructor(uint256 initialSupply) ERC20("Lido's stETH", "stETH") {
        _mint(msg.sender, initialSupply);
    }

    function mintFor(address who, uint256 _sharesAmount) external {
        _mint(who, _sharesAmount);
    }

    function getPooledEthByShares(
        uint256 _sharesAmount
    ) external view returns (uint256) {
        // 1:1 stETH to pufETH
        return _sharesAmount;
    }

    function getSharesByPooledEth(
        uint256 _pooledEthAmount
    ) external view returns (uint256) {
        // 1:1 stETH to pufETH
        return _pooledEthAmount;
    }

    function submit(address _referral) external payable returns (uint256) {
        return 1 ether;
    }
}

contract EigenLayer is IEigenLayer {
    IStETH public constant stETH =
        IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    function depositStETH(uint256 _stETHAmount) external returns (uint256) {
        stETH.transferFrom(msg.sender, address(this), _stETHAmount);
        return _stETHAmount;
    }
}

contract StETHVault is IStETHVault {
    uint256 MAX_APPROVAL = ~uint256(0);
    IEigenLayer public constant EIGENLAYER =
        IEigenLayer(0xdAC17F958D2ee523a2206206994597C13D831ec7); // todo

    IStETH public constant stETH =
        IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    constructor() public {
        stETH.approve(address(EIGENLAYER), MAX_APPROVAL);
    }

    // Deposit stETH for EigenPoints
    function depositToEigenLayer(uint256 amount) external returns (uint256) {
        return EIGENLAYER.depositStETH(amount);
    }
}

contract PufETHTest is Test {
    PufETH public pufETH;
    StETH public stETHContract;
    ITestStETH public constant stETH =
        ITestStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IEigenLayer public constant EIGENLAYER =
        IEigenLayer(0xdAC17F958D2ee523a2206206994597C13D831ec7); // todo
    IStETHVault stETHVault;
    IPufETHVault rPufETHVault = IPufETHVault(address(104));

    address alice = address(101);
    uint256 aliceInitBalance = 100 ether;

    function setUp() public {
        // Force write to stETH address
        stETHContract = new StETH(0);
        vm.etch(address(stETH), address(stETHContract).code);
        stETH.mintFor(alice, aliceInitBalance);

        // Force write to EIGENLAYER address
        EigenLayer eigenContract = new EigenLayer();
        vm.etch(address(EIGENLAYER), address(eigenContract).code);

        // Create new stETH vault
        StETHVault stETHVaultContract = new StETHVault();
        stETHVault = IStETHVault(address(stETHVaultContract));

        pufETH = new PufETH();
        pufETH.setStETHVault(address(stETHVault));
        pufETH.setRPufETHVault(address(rPufETHVault));
    }

    function testSetup() public {
        assertEq(pufETH.name(), "PufETH liquid restaking token");
        assertEq(pufETH.symbol(), "pufETH");
    }

    function test_mintStETH() public {
        stETH.mintFor(alice, 1 ether);
        assert(stETH.balanceOf(alice) == aliceInitBalance + 1 ether);
        assert(stETH.totalSupply() == aliceInitBalance + 1 ether);
    }

    function test_mintPufETH(uint256 amount) public {
        amount = bound(amount, 0.00001 ether, stETH.balanceOf(alice));
        // Allow stETH to be sent to pufETH contract
        assert(stETH.allowance(alice, address(pufETH)) == 0);
        vm.startPrank(alice);
        stETH.approve(address(pufETH), stETH.balanceOf(alice));
        assert(
            stETH.allowance(alice, address(pufETH)) == stETH.balanceOf(alice)
        );

        // deposit stETH
        pufETH.depositStETH(amount);

        // stETH transfered to vault
        assert(stETH.balanceOf(alice) == aliceInitBalance - amount);
        assert(stETH.balanceOf(address(pufETH)) == 0);
        assert(stETH.balanceOf(address(pufETH.stETHVault())) == amount);

        // pufETH minted to alice
        assert(pufETH.balanceOf(address(pufETH)) == 0);
        assert(pufETH.balanceOf(alice) == amount);
        assert(pufETH.totalSupply() == pufETH.balanceOf(alice));
        assert(pufETH.totalSupply() == stETH.getSharesByPooledEth(amount));
        assert(pufETH.totalSupply() == amount);
    }

    function test_depositEigenLayer(uint256 amount) public {
        amount = bound(amount, 0.00001 ether, stETH.balanceOf(alice));
        // Allow stETH to be sent to pufETH contract
        vm.startPrank(alice);
        stETH.approve(address(pufETH), stETH.balanceOf(alice));

        // deposit stETH
        pufETH.depositStETH(amount);
        vm.stopPrank();

        // deposit stETH to EigenLayer
        uint256 deposited = pufETH.depositToEigenLayer(amount);
        assertEq(deposited, amount);


        // stETH left to EigenLayer
        assertEq(stETH.balanceOf(address(stETHVault)), 0);
        assertEq(stETH.balanceOf(address(EIGENLAYER)), amount);
        assertEq(stETH.balanceOf(alice), aliceInitBalance - amount);
        assertEq(pufETH.balanceOf(alice), amount);
    }
}
