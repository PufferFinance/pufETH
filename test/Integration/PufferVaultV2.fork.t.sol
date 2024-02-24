// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { ERC4626Upgradeable } from "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { TestHelper } from "../TestHelper.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { PufferVaultV2 } from "../../src/PufferVaultV2.sol";
import { ROLE_ID_DAO, ROLE_ID_PUFFER_PROTOCOL } from "../../script/Roles.sol";

contract PufferVaultV2ForkTest is TestHelper {
    address pufferWhale = 0xd164B614FdE7939078c7558F9680FA32f01aed77;

    // Sanity check
    function test_sanity() public {
        assertEq(pufferVault.name(), "pufETH", "name");
        assertEq(pufferVault.symbol(), "pufETH", "symbol");
        assertEq(pufferVault.decimals(), 18, "decimals");
        assertEq(pufferVault.asset(), address(_WETH), "asset");
        assertEq(pufferVault.getPendingLidoETHAmount(), 0, "0 pending lido eth");
        assertEq(pufferVault.totalAssets(), 351755.122828329778282991 ether, "total assets");
        assertEq(pufferVault.getRemainingAssetsDailyWithdrawalLimit(), 100 ether, "daily withdrawal limit");
        assertEq(pufferVault.getELBackingEthAmount(), 341562.667703458494350801 ether, "0 EL backing eth"); // mainnet fork 19271279);
    }

    function test_max_deposit() public giveToken(MAKER_VAULT, address(_WETH), alice, 100 ether) {
        assertEq(pufferVault.maxDeposit(alice), type(uint256).max, "max deposit");
    }

    function test_max_withdrawal() public giveToken(MAKER_VAULT, address(_WETH), alice, 100 ether) {
        // Alice doesn't have any pufETH
        assertEq(pufferVault.maxWithdraw(alice), 0, "max withdraw");
        assertEq(pufferVault.maxRedeem(alice), 0, "max maxRedeem");

        // Whale has more than 100 ether, but the limit is 100 eth
        assertEq(pufferVault.maxWithdraw(pufferWhale), 100 ether, "max withdraw");
        // pufETH is worth more than ETH
        assertEq(pufferVault.maxRedeem(pufferWhale), 99.811061309125114006 ether, "max redeem");
    }

    function test_setDailyWithdrawalLimit() public {
        address dao = makeAddr("dao");

        // Grant DAO role to 'dao' address
        vm.prank(address(timelock));
        accessManager.grantRole(ROLE_ID_DAO, dao, 0);

        // Whale has more than 100 ether, but the limit is 100 eth
        assertEq(pufferVault.maxWithdraw(pufferWhale), 100 ether, "max withdraw");

        // Set the new limit
        uint96 newLimit = 1000 ether;
        vm.prank(dao);
        pufferVault.setDailyWithdrawalLimit(newLimit);

        assertEq(pufferVault.getRemainingAssetsDailyWithdrawalLimit(), newLimit, "daily withdrawal limit");
        // Shares amount
        uint256 maxRedeem = pufferVault.maxRedeem(pufferWhale);
        // If we convert shares to assets, it should be equal to the new limit
        assertEq(pufferVault.convertToAssets(maxRedeem), 1000 ether, "max redeem converted to assets");
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

    function test_deposit_fails_when_not_enough_funds()
        public
        giveToken(MAKER_VAULT, address(_WETH), alice, 100 ether)
    {
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

        // The remaining limit is 0, because the whale already withdrew 20 ether today
        assertEq(pufferVault.getRemainingAssetsDailyWithdrawalLimit(), 0, "0 left");
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
        emit PufferVaultV2.TransferredETH(mockProtocol, 10 ether);
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

        assertEq(mockProtocol.balance, 10 ether, "protocol ETH after");
    }

    function test_redeem_fails_if_no_eth_seeded() public withCaller(pufferWhale) {
        // mainnet vault start with 0 eth
        assertEq(address(pufferVault).balance, 0 ether, "vault ETH");

        uint256 maxWhaleRedeemableShares = pufferVault.maxRedeem(pufferWhale);

        vm.expectRevert();
        pufferVault.redeem(maxWhaleRedeemableShares, pufferWhale, pufferWhale);
    }

    function test_redeem_succeeds_if_seeded_with_eth() public withCaller(pufferWhale) {
        // mainnet vault start with 0 eth
        assertEq(address(pufferVault).balance, 0 ether, "vault ETH");

        // fill it so there is something to redeem
        vm.deal(address(pufferVault), 100 ether);
        assertEq(address(pufferVault).balance, 100 ether, "vault ETH");

        // before state
        uint256 assetsBefore = pufferVault.totalAssets();
        uint256 sharesBefore = pufferVault.totalSupply();
        uint256 whaleShares = pufferVault.balanceOf(pufferWhale);

        // redeem all of whale's shares
        uint256 maxWhaleRedeemableShares = pufferVault.maxRedeem(pufferWhale);
        uint256 redeemedAssets = pufferVault.redeem(maxWhaleRedeemableShares, pufferWhale, pufferWhale);

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

        uint256 wethShares = pufferVault.deposit(depositAmount, alice);
        uint256 stETHShares = pufferVault.depositStETH(depositAmount, alice);
        uint256 ethShares = pufferVault.depositETH{ value: depositAmount }(alice);

        assertEq(wethShares, stETHShares, "weth steth shares");
        assertEq(stETHShares, ethShares, "eth steth shares");

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

        // Should be unchanged
        assertApproxEqAbs(pufferVault.totalAssets(), assetsBefore, 1e9, "asset change");
        assertApproxEqAbs(pufferVault.totalSupply(), sharesBefore, 1e9, "shares change");
    }
}
