// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";

import {PufETH} from "../src/PufETH.sol";
import {IPufETH} from "../src/interface/IPufETH.sol";
import {IPufferPool} from "../src/interface/IPufferPool.sol";
import {IStETH} from "../src/interface/IStETH.sol";
import {IStETHVault} from "../src/interface/IStETHVault.sol";
import {IPufETHVault} from "../src/interface/IPufETHVault.sol";
import {IEigenLayer} from "../src/interface/IEigenLayer.sol";

import {StETH, ITestStETH} from "test/mocks/StETH.sol";
import {EigenLayer} from "test/mocks/EigenLayer.sol";
import {StETHVault} from "test/mocks/StETHVault.sol";

contract StETHVaultTest is Test {
    StETH public stETHContract;
    ITestStETH public constant stETH =
        ITestStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IEigenLayer public constant EIGENLAYER =
        IEigenLayer(0xdAC17F958D2ee523a2206206994597C13D831ec7); // todo
    IStETHVault stETHVault;

    StETHVault stETHVaultContract;

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
        stETHVaultContract = new StETHVault();
        stETHVault = IStETHVault(address(stETHVaultContract));
    }

    function testSetup() public {
        assertEq(stETH.balanceOf(address(stETHVault)), 0);
    }

    function test_depositEigenLayer(uint256 amount) public {
        amount = bound(amount, 0.00001 ether, 10000000 ether);
        stETH.mintFor(address(stETHVault), amount);

        assertEq(stETH.balanceOf(address(stETHVault)), amount);

        // deposit stETH to EigenLayer
        uint256 deposited = stETHVault.depositToEigenLayer(amount);
        assertEq(deposited, amount);

        // stETH left to EigenLayer
        assertEq(stETH.balanceOf(address(stETHVault)), 0);
        assertEq(stETH.balanceOf(address(EIGENLAYER)), amount);
    }

    function test_withdrawEigenLayer(uint256 amount) public {
        amount = bound(amount, 0.00001 ether, 10000000 ether);
        stETH.mintFor(address(stETHVault), amount);

        assertEq(stETH.balanceOf(address(stETHVault)), amount);

        // deposit stETH to EigenLayer
        uint256 deposited = stETHVault.depositToEigenLayer(amount);
        assertEq(deposited, amount);

        // stETH left to EigenLayer
        assertEq(stETH.balanceOf(address(stETHVault)), 0);
        assertEq(stETH.balanceOf(address(EIGENLAYER)), amount);

        // start withdrawing stETH from EigenLayer
        bytes32 withdrawalHash = stETHVault.queueWithdrawalFromEigenLayer(amount);

        // complete withdrawing stETH from EigenLayer
        stETHVault.completeWithdrawalFromEigenLayer(amount);

        // stETH returned to stETHVault
        assertEq(stETH.balanceOf(address(stETHVault)), amount);
        assertEq(stETH.balanceOf(address(EIGENLAYER)), 0);
    }
}
