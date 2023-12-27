// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console2 } from "forge-std/Test.sol";
import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";

import { PufETH } from "../src/PufETH.sol";
import { IPufETH } from "../src/interface/IPufETH.sol";
import { IPufferPool } from "../src/interface/IPufferPool.sol";
import { IStETH } from "../src/interface/IStETH.sol";
import { IStETHVault } from "../src/interface/IStETHVault.sol";
import { IPufETHVault } from "../src/interface/IPufETHVault.sol";
import { IEigenLayer } from "../src/interface/IEigenLayer.sol";

import { StETH, ITestStETH } from "test/mocks/StETH.sol";
import { EigenLayer } from "test/mocks/EigenLayer.sol";
import { StETHVault } from "test/mocks/StETHVault.sol";

contract PufETHTest is Test {
    PufETH public pufETH;
    StETH public stETHContract;
    ITestStETH public constant stETH = ITestStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IEigenLayer public constant EIGENLAYER = IEigenLayer(0xdAC17F958D2ee523a2206206994597C13D831ec7); // todo
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
        assert(stETH.allowance(alice, address(pufETH)) == stETH.balanceOf(alice));

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
}
