// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { TestHelper } from "../TestHelper.sol";
import { IPufferVaultV2 } from "../../src/interface/IPufferVaultV2.sol";

contract PufferVaultV2SandwichTest is TestHelper {
    address pufferWhale = 0xd164B614FdE7939078c7558F9680FA32f01aed77;

    function setUp() public virtual override {
        // Cancun upgrade
        vm.createSelectFork(vm.rpcUrl("mainnet"), 19504381); // ~ 2024-03-24 13:24:23)

        // Setup contracts that are deployed to mainnet
        _setupLiveContracts();

        // Upgrade to latest version
        _upgradeToMainnetPuffer();
    }

    // Rebase increases Vault's totalAssets by +30~ eth
    function test_rebase() public {
        uint256 assetsBefore = pufferVault.totalAssets();

        // Rebase lido is +30.7 ETH for the Vault
        _rebaseLido();

        uint256 assetsAfter = pufferVault.totalAssets();

        assertGt(assetsAfter, assetsBefore, "assetsAfter > assetsBefore");
        assertEq(assetsAfter - assetsBefore, 30.747233933014735819 ether, "30 eth rebase");
    }

    // Attacker tries to use own capital to sandwich the Vault's withdrawal
    // Sandwich attack can'e be in one transaction, it must be a MEV block
    function test_sandwich_v2() public {
        // Give ETH to the depositor(this contract)
        vm.deal(address(this), 100 ether);

        // Give ETH to the PufferVault (withdrawal liqudiity)
        vm.deal(address(pufferVault), 130 ether);

        // deposit 100 ETH
        uint256 pufETHReceived = pufferVault.depositETH{ value: 100 ether }(address(this));

        // Rebase lido is +30.7 ETH for the Vault
        _rebaseLido();

        // Withdraw
        pufferVault.withdraw(pufferVault.maxWithdraw(address(this)), address(this), address(this));

        // Attacker got less than 100 ETH
        assertEq(_WETH.balanceOf(address(this)), 99.018071600759029089 ether, "~ 99 ether received");
    }

    // Even with fees 0, it is not really worth it to sandwich the Vault
    // An attack with 99 ETH would only get 0.008 ETH profit (excluding gas fees)
    // The attacked would need to have 100 ETH/WETH for this to be profitable and he would need to sandwich the Vault in a MEV block
    function test_sandwich_v2_zero_withdrawal_fee() public {
        // Set fees to 0
        // Timelock.sol is the admin of AccessManager
        vm.startPrank(address(timelock));
        vm.expectEmit(true, true, true, true);
        emit IPufferVaultV2.ExitFeeBasisPointsSet(100, 0);
        pufferVault.setExitFeeBasisPoints(0);
        vm.stopPrank();

        // Give ETH to the depositor(this contract)
        vm.deal(address(this), 99 ether);

        // Give ETH to the PufferVault (withdrawal liqudiity)
        vm.deal(address(pufferVault), 130 ether);

        // deposit 100 ETH
        uint256 pufETHReceived = pufferVault.depositETH{ value: 99 ether }(address(this));

        // Rebase lido is +30.7 ETH for the Vault
        _rebaseLido();

        // Withdraw
        pufferVault.withdraw(pufferVault.maxWithdraw(address(this)), address(this), address(this));

        // Attacker got less than 100 ETH
        assertEq(_WETH.balanceOf(address(this)), 99.008169815526098175 ether, "~ 99 ether received");
        // ~ 0.08 ETH profit doesn't seem worth the effort
    }

    function _rebaseLido() internal {
        // Simulates stETH rebasing by fast-forwarding block 19504382 where Lido oracle rebased.
        // Submits the same call data as the Lido oracle.
        // https://etherscan.io/tx/0x0a80282625c00aaa5b224011b35c3ac56783e62b2f7d55fc1550a0945245a8a7
        vm.roll(19504382);
        vm.startPrank(0xc79F702202E3A6B0B6310B537E786B9ACAA19BAf); // Lido's whitelisted Oracle
        (bool success,) = LIDO_ACCOUNTING_ORACLE.call(
            hex"fc7377cd000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000084d31f000000000000000000000000000000000000000000000000000000000005252e0000000000000000000000000000000000000000000000000022abcbe40e8f6500000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000000000000000000000000000000000000000022000000000000000000000000000000000000000000000026d9c46441fbb977e00000000000000000000000000000000000000000000000006e51877e064ce1b1900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000003c0abf5096c484be3c46da300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001958bfceee23b63bd94cf905d77f457004f9972d768450eb9a9ae2d564adaf56c000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000086ce00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000007985"
        );
        assertTrue(success, "oracle rebase failed");
        vm.stopPrank();
    }
}
