// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {PufETH, IStETH, IVault} from "../src/PufETH.sol";
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
        return 1 ether;
    }

    function getSharesByPooledEth(
        uint256 _pooledEthAmount
    ) external view returns (uint256) {
        return 1 ether;
    }

    function submit(address _referral) external payable returns (uint256) {
        return 1 ether;
    }
}

contract PufETHTest is Test {
    PufETH public pufETH;
    StETH public stETHContract;
    ITestStETH public constant stETH =
        ITestStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IVault stETHVault = IVault(address(103));
    IVault rPufETHVault = IVault(address(104));

    address alice = address(101);
    uint256 aliceInitBalance = 100 ether;

    function setUp() public {
        pufETH = new PufETH();
        stETHContract = new StETH(0);

        // Force write to stETH address
        vm.etch(address(stETH), address(stETHContract).code);

        stETH.mintFor(alice, aliceInitBalance);

        pufETH.setStETHVault(address(stETHVault));
        pufETH.setRPufETHVault(address(rPufETHVault));
    }

    function testSetup() public {
        assertEq(pufETH.name(), "PufETH liquid restaking token");
        assertEq(pufETH.symbol(), "pufETH");
    }

    function test_mintStETH() public {
        stETH.mintFor(alice, 1);
        assert(stETH.balanceOf(alice) == aliceInitBalance + 1);
        assert(stETH.totalSupply() == aliceInitBalance + 1);
    }

    function test_mintPufETH() public {
        // Allow stETH to be sent to pufETH contract
        assert(stETH.allowance(alice, address(pufETH)) == 0);
        vm.startPrank(alice);
        stETH.approve(address(pufETH), stETH.balanceOf(alice));
        assert(stETH.allowance(alice, address(pufETH)) == stETH.balanceOf(alice));

        // deposit stETH
        uint256 amount = 10 ether;
        pufETH.depositStETH(amount);

        // stETH transfered to vault
        assert(stETH.balanceOf(alice) == aliceInitBalance - amount);
        assert(stETH.balanceOf(address(pufETH)) == 0);
        assert(stETH.balanceOf(address(pufETH.stETHVault())) == amount);

        // pufETH minted to alice
        assert(pufETH.balanceOf(address(pufETH)) == 0);
        assert(pufETH.totalSupply() == pufETH.balanceOf(alice));
        assert(pufETH.totalSupply() == stETH.getSharesByPooledEth(amount));
    }
}
