// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { TestHelper } from "../TestHelper.sol";

contract PufferVaultV2ForkTest is TestHelper {
    function test_max_deposit() public giveToken(MAKER_VAULT, address(_WETH), alice, 100 ether) {
        assertEq(pufferVault.maxDeposit(alice), type(uint256).max, "max deposit");
    }

    function test_max_withdrawal() public giveToken(MAKER_VAULT, address(_WETH), alice, 100 ether) {
        // Alice doesn't have any pufETH
        assertEq(pufferVault.maxWithdraw(alice), 0, "max withdraw");
        assertEq(pufferVault.maxRedeem(alice), 0, "max maxRedeem");

        // Justin Sun is big puffer whale? or big puffer? hmm..
        assertEq(pufferVault.maxWithdraw(0x176F3DAb24a159341c0509bB36B833E7fdd0a132), 100 ether, "max withdraw justin");
        // pufETH is worth more than ETH
        assertEq(
            pufferVault.maxRedeem(0x176F3DAb24a159341c0509bB36B833E7fdd0a132),
            99.811061309125114006 ether,
            "max redeem justin"
        );
    }

    // Sanity check
    function test_sanity() public {
        assertEq(pufferVault.name(), "pufETH", "name");
        assertEq(pufferVault.symbol(), "pufETH", "symbol");
        assertEq(pufferVault.decimals(), 18, "decimals");
        assertEq(pufferVault.asset(), address(_WETH), "asset");
        assertEq(pufferVault.totalAssets(), 351755.122828329778282991 ether, "total assets");
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
}
