// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { ERC4626Upgradeable } from "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { TestHelper } from "../TestHelper.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { IPufferVaultV2 } from "../../src/interface/IPufferVaultV2.sol";
import { ROLE_ID_DAO, ROLE_ID_PUFFER_PROTOCOL } from "../../script/Roles.sol";
import { UUPSUpgradeable } from "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract PufferVaultV2ForkTest is TestHelper {
    address pufferWhale = 0xd164B614FdE7939078c7558F9680FA32f01aed77;

    function setUp() public virtual override {
        // Cancun upgrade
        vm.createSelectFork(vm.rpcUrl("mainnet"), 19431593); //(Mar-14-2024 06:53:11 AM +UTC)

        // Setup contracts that are deployed to mainnet
        _setupLiveContracts();

        // Upgrade to latest version
        _upgradeToMainnetPuffer();
    }

    // Sanity check
    function test_sanity() public {
        assertEq(pufferVault.name(), "pufETH", "name");
        assertEq(pufferVault.symbol(), "pufETH", "symbol");
        assertEq(pufferVault.decimals(), 18, "decimals");
        assertEq(pufferVault.asset(), address(_WETH), "asset");
        assertEq(pufferVault.getPendingLidoETHAmount(), 0, "0 pending lido eth");
        assertEq(pufferVault.totalAssets(), 368072.286049064583783628 ether, "total assets");
        assertEq(pufferVault.getRemainingAssetsDailyWithdrawalLimit(), 100 ether, "daily withdrawal limit");
        assertEq(pufferVault.getELBackingEthAmount(), 342289.36625576203463247 ether, "0 EL backing eth"); // mainnet fork 19431593);
        assertEq(pufferVault.getExitFeeBasisPoints(), 100, "1% withdrawal fee");
    }

    // Deposit & Withdrawal in the same tx is forbidden. This is a security measure to prevent vault griefing by using flash loans.
    function test_deposit_and_withdrawal_same_tx() public withCaller(alice) {
        // In test environment, we deploy and use src/PufferVaultV2Tests.sol that has the markDeposit modifier disabled
        // Foundry tests are executing all tests from the same transaction, and if it wasn't disabled, pretty much every test would fail.

        // With that code PufferVaultV2Tests deployed, we can test the deposit and withdrawal in the same transaction
        vm.deal(alice, 2 ether);
        pufferVault.depositETH{ value: 1 ether }(alice);
        pufferVault.withdraw(pufferVault.maxWithdraw(alice), alice, alice);

        // After we made sure that it works, we can re-enable the modifier by upgrading to a real mainnet `PufferVaultV2.sol` that has the modifier enabled
        vm.startPrank(COMMUNITY_MULTISIG);
        UUPSUpgradeable(pufferVault).upgradeToAndCall(address(pufferVaultWithBlocking), "");

        // Now, in the same transaction Alice deposits successfully, but the withdrawal reverts
        vm.startPrank(alice);
        pufferVault.depositETH{ value: 1 ether }(alice);

        uint256 maxWithdraw = pufferVault.maxWithdraw(alice);

        // Withdrawal reverts because it is in the same transaction (foundry tests are executing all tests from the same transaction)
        vm.expectRevert(abi.encodeWithSelector(IPufferVaultV2.DepositAndWithdrawalForbidden.selector));
        pufferVault.withdraw(maxWithdraw, alice, alice);
    }

    function test_max_deposit() public giveToken(MAKER_VAULT, address(_WETH), alice, 100 ether) {
        assertEq(pufferVault.maxDeposit(alice), type(uint256).max, "max deposit");
    }

    function test_set_exit_fee_change() public {
        // Get liquidity
        _withdraw_stETH_from_lido();

        // Unauthorized
        vm.expectRevert();
        pufferVault.setExitFeeBasisPoints(200);

        // Default value is 1%
        assertEq(pufferVault.getExitFeeBasisPoints(), 100, "1% withdrawal fee");

        uint256 sharesRequiredBefore = pufferVault.previewWithdraw(10 ether);

        // Timelock.sol is the admin of AccessManager
        vm.startPrank(address(timelock));
        vm.expectEmit(true, true, true, true);
        emit IPufferVaultV2.ExitFeeBasisPointsSet(100, 200);
        pufferVault.setExitFeeBasisPoints(200);

        // After
        assertEq(pufferVault.getExitFeeBasisPoints(), 200, "2% withdrawal fee");

        // Because it is a bigger fee, the shares required to withdraw 100 ETH is bigger
        uint256 sharesRequiredAfter = pufferVault.previewWithdraw(10 ether);
        assertGt(sharesRequiredAfter, sharesRequiredBefore, "shares required before must be bigger");

        // Withdraw assets
        vm.startPrank(pufferWhale);
        uint256 sharesWithdrawn = pufferVault.withdraw(10 ether, pufferWhale, pufferWhale);

        vm.startPrank(address(timelock));
        vm.expectEmit(true, true, true, true);
        emit IPufferVaultV2.ExitFeeBasisPointsSet(200, 0);
        pufferVault.setExitFeeBasisPoints(0);

        assertEq(pufferVault.getExitFeeBasisPoints(), 0, "0");

        // Withdraw the same amount of assets again
        vm.startPrank(pufferWhale);
        uint256 sharesWithdrawnAfter = pufferVault.withdraw(10 ether, pufferWhale, pufferWhale);

        assertLt(sharesWithdrawnAfter, sharesWithdrawn, "no fee = less shares needed");
    }

    function test_max_withdrawal() public giveToken(MAKER_VAULT, address(_WETH), alice, 100 ether) {
        // Alice doesn't have any pufETH
        assertEq(pufferVault.maxWithdraw(alice), 0, "max withdraw");
        assertEq(pufferVault.maxRedeem(alice), 0, "max maxRedeem");

        // Whale has more than 100 ether, but the limit is 100 eth
        assertEq(pufferVault.maxWithdraw(pufferWhale), 100 ether, "max withdraw");
        // Because of the withdrawal fee, the maxRedeem is bigger than the maxWithdraw
        assertEq(pufferVault.maxRedeem(pufferWhale), 100.595147442558494386 ether, "max redeem");
    }

    function test_setDailyWithdrawalLimit() public {
        // Get withdrawal liquidity
        _withdraw_stETH_from_lido();

        address dao = makeAddr("dao");

        // Grant DAO role to 'dao' address
        vm.startPrank(address(timelock));
        accessManager.grantRole(ROLE_ID_DAO, dao, 0);

        // Whale has more than 100 ether, but the limit is 100 eth
        assertEq(pufferVault.maxWithdraw(pufferWhale), 100 ether, "max withdraw");

        vm.startPrank(pufferWhale);
        pufferVault.withdraw(pufferVault.maxWithdraw(pufferWhale), pufferWhale, pufferWhale);

        assertEq(pufferVault.getRemainingAssetsDailyWithdrawalLimit(), 0, "remaining assets daily withdrawal limit");

        // Set the new limit
        uint96 newLimit = 1000 ether;
        vm.startPrank(dao);
        vm.expectEmit(true, true, true, true);
        emit IPufferVaultV2.DailyWithdrawalLimitReset();
        pufferVault.setDailyWithdrawalLimit(newLimit);

        assertEq(pufferVault.getRemainingAssetsDailyWithdrawalLimit(), newLimit, "daily withdrawal limit");
        // Shares amount
        uint256 maxRedeem = pufferVault.maxRedeem(pufferWhale);
        // If we convert shares to assets, it should be equal to the new limit + 10 (1% is the withdrawal fee)
        assertEq(pufferVault.convertToAssets(maxRedeem), 1010 ether, "max redeem converted to assets");
    }

    function test_withdraw_fee() public {
        // Get withdrawal liquidity
        _withdraw_stETH_from_lido();

        address recipient = makeAddr("assetsRecipient");

        uint256 expectedSharesWithdrawn = pufferVault.previewWithdraw(10 ether);

        assertEq(_WETH.balanceOf(recipient), 0, "got 0 weth");

        // Withdraw
        vm.startPrank(pufferWhale);
        uint256 sharesWithdrawn = pufferVault.withdraw(10 ether, recipient, pufferWhale);
        vm.stopPrank();

        // Recipient will get 10 WETH
        assertEq(_WETH.balanceOf(recipient), 10 ether, "got +10 weth");

        assertEq(expectedSharesWithdrawn, sharesWithdrawn, "must match");

        // The exchange rate changes after the first withdrawal, because of the fee
        // The second withdrawal will burn less shares than the first one
        uint256 expectedShares = pufferVault.previewWithdraw(10 ether);

        assertLt(expectedShares, sharesWithdrawn, "shares must be less than previous");

        vm.startPrank(pufferWhale);
        pufferVault.redeem(expectedShares, recipient, pufferWhale);

        assertEq(_WETH.balanceOf(recipient), 20 ether, "+10 weth");
    }

    function test_redemption_fee() public {
        // Get withdrawal liquidity
        _withdraw_stETH_from_lido();

        address recipient = makeAddr("assetsRecipient");

        // This much shares will get us 10 WETH
        uint256 expectedSharesWithdrawn = pufferVault.previewWithdraw(10 ether);

        uint256 expectedAssetsOut = pufferVault.previewRedeem(expectedSharesWithdrawn);

        assertEq(_WETH.balanceOf(recipient), 0, "got 0 weth");

        // // Withdraw
        vm.startPrank(pufferWhale);
        uint256 assetsOut = pufferVault.redeem(expectedSharesWithdrawn, recipient, pufferWhale);
        vm.stopPrank();

        // // // Recipient will get 10 WETH
        assertEq(_WETH.balanceOf(recipient), 10 ether, "got +10 weth");

        assertEq(expectedAssetsOut, assetsOut, "must match");
        assertEq(assetsOut, 10 ether, "must match eth");

        // The exchange rate changes slightly after the first withdrawal, because of the withdrawal fee
        // The same amount of
        uint256 expectedAssets = pufferVault.previewRedeem(expectedSharesWithdrawn);

        assertGt(expectedAssets, 10 ether, "second withdrawal previewRedeem");

        vm.startPrank(pufferWhale);
        pufferVault.redeem(expectedSharesWithdrawn, recipient, pufferWhale);

        uint256 recipientBalance = _WETH.balanceOf(recipient);

        assertGt(recipientBalance, 20 ether, "+10 weth");

        // Assert the daily withdrawal limit
        assertEq(
            pufferVault.getRemainingAssetsDailyWithdrawalLimit(), 100 ether - recipientBalance, "daily withdrawal limit"
        );
    }

    function test_daily_limit_reset() public {
        _withdraw_stETH_from_lido();

        vm.startPrank(pufferWhale);
        assertEq(pufferVault.getRemainingAssetsDailyWithdrawalLimit(), 100 ether, "daily withdrawal limit");

        assertEq(pufferVault.maxWithdraw(pufferWhale), 100 ether, "max withdraw");
        pufferVault.withdraw(50 ether, pufferWhale, pufferWhale);

        assertEq(pufferVault.getRemainingAssetsDailyWithdrawalLimit(), 50 ether, "daily withdrawal limit reduced");

        vm.warp(block.timestamp + 1 days);

        assertEq(pufferVault.getRemainingAssetsDailyWithdrawalLimit(), 100 ether, "daily withdrawal limit reduced");

        assertEq(pufferVault.maxWithdraw(pufferWhale), 100 ether, "max withdraw");
        pufferVault.withdraw(22 ether, pufferWhale, pufferWhale);

        assertEq(pufferVault.getRemainingAssetsDailyWithdrawalLimit(), 78 ether, "daily withdrawal limit reduced");
    }

    function test_withdrawal() public {
        // Get withdrawal liquidity
        _withdraw_stETH_from_lido();

        vm.startPrank(pufferWhale);
        assertEq(pufferVault.getRemainingAssetsDailyWithdrawalLimit(), 100 ether, "daily withdrawal limit");

        assertEq(pufferVault.maxWithdraw(pufferWhale), 100 ether, "max withdraw");
        pufferVault.withdraw(50 ether, pufferWhale, pufferWhale);

        assertEq(pufferVault.getRemainingAssetsDailyWithdrawalLimit(), 50 ether, "daily withdrawal limit reduced");
        assertEq(pufferVault.maxWithdraw(pufferWhale), 50 ether, "leftover max withdraw");

        pufferVault.withdraw(50 ether, pufferWhale, pufferWhale);
        assertEq(pufferVault.maxWithdraw(pufferWhale), 0 ether, "no leftover max withdraw");
        assertEq(pufferVault.getRemainingAssetsDailyWithdrawalLimit(), 0 ether, "everything withdrawn");
    }

    function test_withdrawal_transfers_to_receiver() public {
        // Get withdrawal liquidity
        _withdraw_stETH_from_lido();

        // Initial state
        assertEq(_WETH.balanceOf(address(alice)), 0, "alice balance");
        uint256 whaleShares = pufferVault.balanceOf(pufferWhale);

        // Withdraw with alice as receiver
        vm.startPrank(pufferWhale);
        uint256 sharesBurned = pufferVault.withdraw({ assets: 50 ether, receiver: alice, owner: pufferWhale });
        vm.stopPrank();

        // Alice received 50 wETH
        assertEq(_WETH.balanceOf(address(alice)), 50 ether, "alice balance");

        // Whale burned shares
        assertApproxEqAbs(pufferVault.balanceOf(pufferWhale), whaleShares - sharesBurned, 1e9, "asset change");
    }

    function test_withdrawal_succeeds_with_allowance() public {
        // Get withdrawal liquidity
        _withdraw_stETH_from_lido();

        // Initial state
        assertEq(_WETH.balanceOf(address(alice)), 0, "alice balance");
        uint256 whaleShares = pufferVault.balanceOf(pufferWhale);

        // pufferWhale approves alice to burn their pufETH
        vm.startPrank(pufferWhale);
        pufferVault.approve(address(alice), type(uint256).max);
        vm.stopPrank();

        // Alice tries to withdraw on behalf of pufferWhale
        vm.startPrank(alice);
        uint256 sharesBurned = pufferVault.withdraw({ assets: 50 ether, receiver: alice, owner: pufferWhale });
        vm.stopPrank();

        // Alice should receives 50 wETH
        assertEq(_WETH.balanceOf(address(alice)), 50 ether, "alice balance");

        // Whale burned shares
        assertApproxEqAbs(pufferVault.balanceOf(pufferWhale), whaleShares - sharesBurned, 1e9, "asset change");
    }

    function test_withdrawal_fails_if_owner_is_not_caller() public {
        // Get withdrawal liquidity
        _withdraw_stETH_from_lido();

        // Initial state
        assertEq(_WETH.balanceOf(address(alice)), 0, "alice balance");

        // Alice tries to withdraw on behalf of pufferWhale
        vm.startPrank(alice);
        vm.expectRevert();
        pufferVault.withdraw({ assets: 50 ether, receiver: alice, owner: pufferWhale });
        vm.stopPrank();

        // Alice should not receive
        assertEq(_WETH.balanceOf(address(alice)), 0 ether, "alice balance");
    }

    function test_withdrawal_fails_when_exceeding_maximum()
        public
        giveToken(MAKER_VAULT, address(_WETH), alice, 100 ether)
    {
        // Get withdrawal liquidity
        _withdraw_stETH_from_lido();

        vm.startPrank(alice);

        // vm.expectRevert(abi.encodeWithSelector(ERC4626Upgradeable.ERC4626ExceededMaxWithdraw.selector, alice, 100 ether + 1)); // failing to encode correctly
        vm.expectRevert();
        pufferVault.withdraw(100 ether + 1, alice, alice);
    }

    // deposit WETH
    function test_deposit() public giveToken(MAKER_VAULT, address(_WETH), alice, 100 ether) withCaller(alice) {
        uint256 depositAmount = 100 ether;
        uint256 estimatedShares = pufferVault.previewDeposit(depositAmount);
        uint256 assetsBefore = pufferVault.totalAssets();
        uint256 sharesBefore = pufferVault.totalSupply();
        _WETH.approve(address(pufferVault), type(uint256).max);
        uint256 gotShares = pufferVault.deposit(depositAmount, alice);
        assertEq(estimatedShares, gotShares, "shares");
        assertLt(gotShares, depositAmount, "shares must be less than deposit");
        assertApproxEqAbs(pufferVault.totalAssets(), assetsBefore + depositAmount, 1e9, "asset change");
        assertApproxEqAbs(pufferVault.totalSupply(), sharesBefore + estimatedShares, 1e9, "shares change");
    }

    function test_deposit_fails_when_not_enough_funds() public {
        vm.expectRevert();
        pufferVault.deposit(100 ether + 1, alice);

        vm.expectRevert();
        pufferVault.depositETH{ value: type(uint256).max }(alice);

        vm.expectRevert();
        pufferVault.depositStETH(100 ether + 1, alice);
    }

    function test_change_withdrawal_limit() public {
        _withdraw_stETH_from_lido();

        address dao = makeAddr("dao");

        // Grant DAO role to 'dao' address
        vm.startPrank(address(timelock));
        accessManager.grantRole(ROLE_ID_DAO, dao, 0);

        vm.startPrank(pufferWhale);
        pufferVault.withdraw(20 ether, pufferWhale, pufferWhale);

        assertEq(pufferVault.getRemainingAssetsDailyWithdrawalLimit(), 80 ether, "daily withdrawal limit");

        // Set the new limit
        uint96 newLimit = 10 ether;
        vm.startPrank(dao);
        pufferVault.setDailyWithdrawalLimit(newLimit);

        // The remaining limit is reset in `setDailyWithdrawalLimit`
        assertEq(pufferVault.getRemainingAssetsDailyWithdrawalLimit(), 10 ether, "10 ether left - limit is reset");
    }

    function test_burn() public withCaller(pufferWhale) {
        vm.expectRevert();
        pufferVault.burn(100 ether);
        // Grant PufferProtocol role to the whale, because he has tokens to burn
        vm.startPrank(address(timelock));
        accessManager.grantRole(ROLE_ID_PUFFER_PROTOCOL, pufferWhale, 0);

        // burn works
        vm.startPrank(pufferWhale);

        uint256 balanceBefore = pufferVault.balanceOf(pufferWhale);

        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(pufferWhale, address(0), 100 ether);
        pufferVault.burn(100 ether);

        uint256 balanceAfter = pufferVault.balanceOf(pufferWhale);
        assertEq(balanceAfter, balanceBefore - 100 ether, "balance");
    }

    function test_transferETH() public {
        // Give ETH liquidity
        _withdraw_stETH_from_lido();

        address mockProtocol = makeAddr("mockProtocol");

        // This contract has no ROLE_ID_PUFFER_PROTOCOL, so this reverts
        vm.expectRevert();
        pufferVault.transferETH(mockProtocol, 10 ether);

        // Grant Protocol role to mockProtocol address
        vm.startPrank(address(timelock));
        accessManager.grantRole(ROLE_ID_PUFFER_PROTOCOL, mockProtocol, 0);

        assertEq(mockProtocol.balance, 0 ether, "protocol ETH");

        vm.startPrank(mockProtocol);
        vm.expectEmit(true, true, true, true);
        emit IPufferVaultV2.TransferredETH(mockProtocol, 10 ether);
        pufferVault.transferETH(mockProtocol, 10 ether);

        assertEq(mockProtocol.balance, 10 ether, "protocol ETH after");
    }

    function test_transferETH_with_weth_liquidity() public giveToken(MAKER_VAULT, address(_WETH), alice, 100 ether) {
        // NO ETH liquidity, but we have WETH

        address mockProtocol = makeAddr("mockProtocol");

        // Grant Protocol role to mockProtocol address
        vm.startPrank(address(timelock));
        accessManager.grantRole(ROLE_ID_PUFFER_PROTOCOL, mockProtocol, 0);

        assertEq(mockProtocol.balance, 0 ether, "protocol ETH");

        vm.startPrank(mockProtocol);
        vm.expectRevert();
        pufferVault.transferETH(mockProtocol, 10 ether);

        // Alice deposits 100 WETH
        vm.startPrank(alice);
        _WETH.approve(address(pufferVault), type(uint256).max);
        pufferVault.deposit(100 ether, alice);

        // Alice tries to transferETH, got no permissions
        vm.expectRevert();
        pufferVault.transferETH(mockProtocol, 10 ether);

        // Now it works
        vm.startPrank(mockProtocol);
        pufferVault.transferETH{ gas: 800000 }(mockProtocol, 10 ether);

        // assertEq(mockProtocol.balance, 10 ether, "protocol ETH after");
    }

    function test_redeem_fails_if_no_eth_seeded() public withCaller(pufferWhale) {
        // mainnet vault start actually has some balance
        assertEq(address(pufferVault).balance, 4433776828572703, "vault ETH");

        uint256 maxWhaleRedeemableShares = pufferVault.maxRedeem(pufferWhale);

        vm.expectRevert();
        pufferVault.redeem(maxWhaleRedeemableShares, pufferWhale, pufferWhale);
    }

    // function test_redeem_succeeds_if_seeded_with_eth() public withCaller(pufferWhale) {
    function test_redeem_succeeds_if_seeded_with_eth() public {
        // mainnet vault start with 0 eth
        assertEq(address(pufferVault).balance, 4433776828572703, "vault ETH");

        // Fill vault with withdrawal liquidity
        _withdraw_stETH_from_lido();

        // before state
        uint256 assetsBefore = pufferVault.totalAssets();
        uint256 sharesBefore = pufferVault.totalSupply();
        uint256 whaleShares = pufferVault.balanceOf(pufferWhale);

        // redeem all of whale's shares
        vm.startPrank(pufferWhale);
        uint256 maxWhaleRedeemableShares = pufferVault.maxRedeem(pufferWhale);
        uint256 redeemedAssets = pufferVault.redeem(maxWhaleRedeemableShares, pufferWhale, pufferWhale);
        vm.stopPrank();

        // no more to redeem
        assertEq(pufferVault.maxRedeem(pufferWhale), 0, "max redeem");

        // vault's assets are reduced
        assertApproxEqAbs(pufferVault.totalAssets(), assetsBefore - redeemedAssets, 1e9, "asset change");
        // vault's shares are reduced
        assertApproxEqAbs(pufferVault.totalSupply(), sharesBefore - maxWhaleRedeemableShares, 1e9, "shares change");
        // whale's shares are reduced
        assertApproxEqAbs(
            pufferVault.balanceOf(pufferWhale), whaleShares - maxWhaleRedeemableShares, 1e9, "shares change"
        );
    }

    function test_redeem_transfers_to_receiver() public {
        // Get withdrawal liquidity
        _withdraw_stETH_from_lido();

        // Initial state
        assertEq(_WETH.balanceOf(address(alice)), 0, "alice balance");
        uint256 whaleShares = pufferVault.balanceOf(pufferWhale);

        // Withdraw with alice as receiver
        vm.startPrank(pufferWhale);
        uint256 assets = pufferVault.redeem({ shares: 50 ether, receiver: alice, owner: pufferWhale });
        vm.stopPrank();

        // Alice received 50 wETH
        assertEq(_WETH.balanceOf(address(alice)), assets, "alice balance");

        // Whale burned shares
        assertApproxEqAbs(pufferVault.balanceOf(pufferWhale), whaleShares - 50 ether, 1e9, "asset change");
    }

    function test_redeem_succeeds_with_allowance() public {
        // Get withdrawal liquidity
        _withdraw_stETH_from_lido();

        // Initial state
        assertEq(_WETH.balanceOf(address(alice)), 0, "alice balance");
        uint256 whaleShares = pufferVault.balanceOf(pufferWhale);

        // pufferWhale approves alice to burn their pufETH
        vm.startPrank(pufferWhale);
        pufferVault.approve(address(alice), type(uint256).max);
        vm.stopPrank();

        // Alice tries to withdraw on behalf of pufferWhale
        vm.startPrank(alice);
        uint256 assets = pufferVault.redeem({ shares: 50 ether, receiver: alice, owner: pufferWhale });
        vm.stopPrank();

        // Alice should receives 50 wETH
        assertEq(_WETH.balanceOf(address(alice)), assets, "alice balance");
        assertApproxEqAbs(pufferVault.balanceOf(pufferWhale), whaleShares - 50 ether, 1e9, "asset change");
    }

    function test_redeem_fails_if_owner_is_not_caller() public {
        // Get withdrawal liquidity
        _withdraw_stETH_from_lido();

        // Initial state
        assertEq(_WETH.balanceOf(address(alice)), 0, "alice balance");

        // Alice tries to withdraw on behalf of pufferWhale
        vm.startPrank(alice);
        vm.expectRevert();
        pufferVault.redeem({ shares: 50 ether, receiver: alice, owner: pufferWhale });
        vm.stopPrank();

        // Alice should not receive
        assertEq(_WETH.balanceOf(address(alice)), 0 ether, "alice balance");
    }

    // mint with WETH
    function test_mint() public giveToken(MAKER_VAULT, address(_WETH), alice, 100 ether) withCaller(alice) {
        uint256 sharesAmount = 5 ether;
        uint256 estimatedAssets = pufferVault.previewMint(5 ether);
        uint256 assetsBefore = pufferVault.totalAssets();
        uint256 sharesBefore = pufferVault.totalSupply();
        _WETH.approve(address(pufferVault), type(uint256).max);
        uint256 gotAssets = pufferVault.mint(sharesAmount, alice);
        assertEq(estimatedAssets, gotAssets, "got assets");
        assertLt(sharesAmount, gotAssets, "shares must be less than deposit");
        assertApproxEqAbs(pufferVault.totalAssets(), assetsBefore + estimatedAssets, 1e9, "asset change");
        assertApproxEqAbs(pufferVault.totalSupply(), sharesBefore + sharesAmount, 1e9, "shares change");
    }

    // ETH and WETH and STETH deposits should give you the same amount of shares
    function test_eth_weth_stETH_deposits()
        public
        giveToken(MAKER_VAULT, address(_WETH), alice, 100 ether)
        giveToken(BLAST_DEPOSIT, address(stETH), alice, 100 ether)
        withCaller(alice)
    {
        uint256 assetsBefore = pufferVault.totalAssets();
        uint256 sharesBefore = pufferVault.totalSupply();

        // 10 ETH, 10 WETH, 10 stETH
        uint256 depositAmount = 10 ether;

        _WETH.approve(address(pufferVault), type(uint256).max);
        stETH.approve(address(pufferVault), type(uint256).max);
        vm.deal(alice, 100 ether);

        uint256 stETHSharesAmount = _ST_ETH.getSharesByPooledEth(depositAmount);

        uint256 wethShares = pufferVault.deposit(depositAmount, alice);
        uint256 stETHShares = pufferVault.depositStETH(stETHSharesAmount, alice);
        uint256 ethShares = pufferVault.depositETH{ value: depositAmount }(alice);

        assertApproxEqAbs(wethShares, stETHShares, 1, "weth steth shares");
        assertApproxEqAbs(stETHShares, ethShares, 1, "eth steth shares");

        assertApproxEqAbs(pufferVault.totalAssets(), assetsBefore + 3 * depositAmount, 1e9, "asset change");
        assertApproxEqAbs(
            pufferVault.totalSupply(), sharesBefore + wethShares + stETHShares + ethShares, 1e9, "shares change"
        );
    }

    // EL Deposits are Paused in the current block
    // function test_el_stETH_deposit() public {
    //     uint256 exchangeRateBefore = pufferVault.previewDeposit(1 ether);
    //     vm.startPrank(OPERATIONS_MULTISIG);
    //     pufferVault.depositToEigenLayer(1000 ether);
    //     uint256 exchangeRateAfterDeposit = pufferVault.previewDeposit(1 ether);
    //     assertEq(exchangeRateBefore, exchangeRateAfterDeposit, "exchange rate must not change after the deposit to EL");
    // }

    function _withdraw_stETH_from_lido() public {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1000 ether; // steth Amount
        amounts[1] = 1000 ether; // steth Amount

        uint256 assetsBefore = pufferVault.totalAssets();
        uint256 sharesBefore = pufferVault.totalSupply();

        vm.startPrank(OPERATIONS_MULTISIG);
        uint256[] memory requestIds = pufferVault.initiateETHWithdrawalsFromLido(amounts);

        assertEq(pufferVault.getPendingLidoETHAmount(), 2000 ether);

        _finalizeWithdrawals(requestIds[1]);

        vm.roll(block.number + 10 days);

        // Claim withdrawals
        pufferVault.claimWithdrawalsFromLido(requestIds);

        // Because we don't simulate an oracle update after we initiateETHWithdrawals, we get less than we sent. `976671819902367` less on 2k ETH
        assertApproxEqAbs(pufferVault.totalAssets(), assetsBefore, 976671819902367, "asset change");
        assertApproxEqAbs(pufferVault.totalSupply(), sharesBefore, 1e9, "shares change");
    }
}
