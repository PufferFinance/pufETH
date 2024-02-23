// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { TestHelper } from "../TestHelper.sol";

contract PufferVaultV2ForkTest is TestHelper {
    address pufferWhale = 0xd164B614FdE7939078c7558F9680FA32f01aed77;

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

    // Sanity check
    function test_sanity() public {
        assertEq(pufferVault.name(), "pufETH", "name");
        assertEq(pufferVault.symbol(), "pufETH", "symbol");
        assertEq(pufferVault.decimals(), 18, "decimals");
        assertEq(pufferVault.asset(), address(_WETH), "asset");
        assertEq(pufferVault.getPendingLidoETHAmount(), 0, "0 pending lido eth");
        assertEq(pufferVault.totalAssets(), 351755.122828329778282991 ether, "total assets");
        assertEq(pufferVault.getRemainingAssetsDailyWithdrawalLimit(), 100 ether, "daily withdrawal limit");
    }

    // deposit WETH
    function test_deposit() public giveToken(MAKER_VAULT, address(_WETH), alice, 100 ether) withCaller(alice) {
        uint256 depositAmount = 100 ether;
        uint256 estimatedShares = pufferVault.previewDeposit(depositAmount);
        _WETH.approve(address(pufferVault), type(uint256).max);
        uint256 gotShares = pufferVault.deposit(depositAmount, alice);
        assertEq(estimatedShares, gotShares, "shares");
        assertLt(gotShares, depositAmount, "shares must be less than deposit");
    }

    // mint with WETH
    function test_mint() public giveToken(MAKER_VAULT, address(_WETH), alice, 100 ether) withCaller(alice) {
        uint256 sharesAmount = 5 ether;
        uint256 estimatedAssets = pufferVault.previewMint(5 ether);
        _WETH.approve(address(pufferVault), type(uint256).max);
        uint256 gotAssets = pufferVault.mint(sharesAmount, alice);
        assertEq(estimatedAssets, gotAssets, "got assets");
        assertLt(sharesAmount, gotAssets, "shares must be less than deposit");
    }

    // ETH and WETH and STETH deposits should give you the same amount of shares
    function test_eth_weth_stETH_deposits()
        public
        giveToken(MAKER_VAULT, address(_WETH), alice, 100 ether)
        giveToken(BLAST_DEPOSIT, address(stETH), alice, 100 ether)
        withCaller(alice)
    {
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

        vm.startPrank(OPERATIONS_MULTISIG);
        uint256[] memory requestIds = pufferVault.initiateETHWithdrawalsFromLido(amounts);
        _finalizeWithdrawals(requestIds[1]);
        vm.roll(block.number + 10 days);

        // Claim withdrawals
        pufferVault.claimWithdrawalsFromLido(requestIds);
    }
}
