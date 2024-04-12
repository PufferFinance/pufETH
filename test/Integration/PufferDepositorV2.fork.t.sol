// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { TestHelper } from "../TestHelper.sol";
import { Permit } from "../../src/structs/Permit.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

contract PufferDepositorV2ForkTest is TestHelper {
    /**
     * @dev Wallet that transferred pufETH to the PufferDepositor by mistake.
     */
    address private constant PUFFER = 0x8A0C1e5cEA8e0F6dF341C005335E7fe5ed18A0a0;

    function setUp() public virtual override {
        vm.createSelectFork(vm.rpcUrl("mainnet"), 19419083); // (2024-03-12 12:45:11) UTC block

        // Setup contracts that are deployed to mainnet
        _setupLiveContracts();

        assertEq(pufferVault.balanceOf(address(pufferDepositor)), 0.201 ether, "pufferDepositor pufETH");
        assertEq(pufferVault.balanceOf(PUFFER), 0, "puffer pufETH before");

        // Upgrade to latest version
        _upgradeToMainnetPuffer();

        assertEq(pufferVault.balanceOf(address(pufferDepositor)), 0 ether, "pufferDepositor 0 pufETH");
        assertEq(pufferVault.balanceOf(PUFFER), 0.201 ether, "returned pufETH");
    }

    // StETH deposit through depositor and directly should mint ~amount
    function test_stETH_permit_deposit_to_self()
        public
        giveToken(BLAST_DEPOSIT, address(stETH), alice, 200 ether)
        withCaller(alice)
    {
        // Deposit amount
        uint256 stETHDepositAmount = 100 ether;
        Permit memory permit = _signPermit(
            _testTemps(
                "alice",
                address(pufferDepositor),
                stETHDepositAmount,
                block.timestamp,
                hex"260e7e1a220ea89b9454cbcdc1fcc44087325df199a3986e560d75db18b2e253"
            )
        );

        // PufferDepositor deposit
        uint256 depositorAmount = pufferDepositor.depositStETH(permit, alice);

        assertEq(depositorAmount, pufferVault.balanceOf(alice), "alice got the tokens");

        stETH.approve(address(pufferVault), stETHDepositAmount);

        uint256 stETHSharesAmount = _ST_ETH.getSharesByPooledEth(stETHDepositAmount);

        // Direct deposit to the Vault
        uint256 directDepositAmount = pufferVault.depositStETH(stETHSharesAmount, alice);

        uint256 depositorAssetsAmount = pufferVault.convertToAssets(depositorAmount);
        uint256 directDepositAssetsAmount = pufferVault.convertToAssets(directDepositAmount);

        assertApproxEqAbs(pufferVault.convertToAssets(depositorAmount), depositorAssetsAmount, 1, "depositor");
        assertApproxEqAbs(
            pufferVault.convertToAssets(directDepositAmount), directDepositAssetsAmount, 1, "direct deposit"
        );

        assertApproxEqAbs(
            depositorAssetsAmount + directDepositAssetsAmount,
            2 * stETHDepositAmount,
            3, // 3 wei difference, because the PufferDepositor already has 1 wei of stETH (leftover)
            "should have ~200 eth worth of assets"
        );

        assertApproxEqAbs(depositorAmount, directDepositAmount, 1, "depositor amount should be ~direct deposit amount");
        assertApproxEqAbs(depositorAssetsAmount, directDepositAssetsAmount, 1, "received assets should be ~equal");
        assertApproxEqAbs(depositorAssetsAmount, stETHDepositAmount, 1, "steth received assets should be ~equal");
    }

    function test_stETH_donation_and_first_depositor_after_donation()
        public
        giveToken(BLAST_DEPOSIT, address(stETH), alice, 100 ether)
        giveToken(BLAST_DEPOSIT, address(stETH), bob, 100 ether)
        withCaller(alice)
    {
        // Alice transfers 1 stETH to the Vault by mistake
        _ST_ETH.transfer(address(pufferDepositor), 1 ether);

        assertEq(pufferVault.balanceOf(alice), 0, "0 pufETH for alice");

        vm.startPrank(bob);

        Permit memory permit = _signPermit(
            _testTemps(
                "bob",
                address(pufferDepositor),
                1 ether,
                block.timestamp,
                hex"260e7e1a220ea89b9454cbcdc1fcc44087325df199a3986e560d75db18b2e253"
            )
        );
        assertEq(0, pufferVault.balanceOf(bob), "bob got 0 pufETH");

        // 1 stETH should be ~
        uint256 expectedAmount = pufferVault.convertToShares(1 ether);

        // Bob deposits 1 stETH via PufferDepositor
        // But his deposit will sweep the stETH.balanceOf(pufferDepositor) as well, meaning he will get shares for Alice's 1 stETH
        uint256 depositorAmount = pufferDepositor.depositStETH(permit, bob);

        assertEq(depositorAmount, pufferVault.balanceOf(bob), "bob got");

        // 3 wei difference, because the PufferDepositor already has 1 wei of stETH (leftover)
        assertApproxEqAbs((expectedAmount * 2), depositorAmount, 3, "bob got more pufETH than expected");

        assertApproxEqAbs(
            pufferVault.convertToAssets(pufferVault.balanceOf(bob)), 2 ether, 3, "2 eth worth of assets for bob"
        );

        assertEq(0, pufferVault.balanceOf(alice), "alice got 0");
    }

    function test_stETH_share_conversion() public {
        uint256 stETHAmount = 100 ether;
        uint256 stETHSharesAmount = _ST_ETH.getSharesByPooledEth(stETHAmount);
        uint256 stETHAmountFromShares = _ST_ETH.getPooledEthByShares(stETHSharesAmount);

        assertApproxEqAbs(stETHAmount, stETHAmountFromShares, 1, "stETH amount should be ~stETH amount from shares");
    }

    function test_stETH_permit_deposit_to_bob()
        public
        giveToken(BLAST_DEPOSIT, address(stETH), alice, 200 ether)
        withCaller(alice)
    {
        Permit memory permit = _signPermit(
            _testTemps(
                "alice",
                address(pufferDepositor),
                100 ether,
                block.timestamp,
                hex"260e7e1a220ea89b9454cbcdc1fcc44087325df199a3986e560d75db18b2e253"
            )
        );

        uint256 depositorAmount = pufferDepositor.depositStETH(permit, bob);

        assertEq(depositorAmount, pufferVault.balanceOf(bob), "bob got the tokens");
        assertEq(0, pufferVault.balanceOf(alice), "alice got 0");
    }

    // stETH approve deposit
    function test_stETH_approve_deposit_to_self()
        public
        giveToken(BLAST_DEPOSIT, address(stETH), alice, 200 ether)
        withCaller(alice)
    {
        uint256 stETHAmount = 100 ether;
        // Create an unsigned permit to call function
        Permit memory unsignedPermit = Permit(0, stETHAmount, 0, 0, 0);
        IERC20(address(stETH)).approve(address(pufferDepositor), stETHAmount);

        uint256 depositorAmount = pufferDepositor.depositStETH(unsignedPermit, alice);

        assertEq(depositorAmount, pufferVault.balanceOf(alice), "alice got the tokens");

        // StETH deposit through depositor and directly should mint the same amount
        stETH.approve(address(pufferVault), stETHAmount);

        uint256 stETHSharesAmount = _ST_ETH.getSharesByPooledEth(stETHAmount);

        uint256 directDepositAmount = pufferVault.depositStETH(stETHSharesAmount, alice);

        uint256 depositorAssetsAmount = pufferVault.convertToAssets(depositorAmount);
        uint256 directDepositAssetsAmount = pufferVault.convertToAssets(directDepositAmount);

        assertApproxEqAbs(depositorAmount, directDepositAmount, 1, "1 wei difference");
        assertApproxEqAbs(depositorAssetsAmount, directDepositAssetsAmount, 1, "received assets should be ~equal");
        assertApproxEqAbs(
            depositorAssetsAmount, stETHAmount, 1, "amount deposited and convertToAssets should be ~equal"
        );
    }

    // stETH approve deposit to bob
    function test_stETH_approve_deposit_to_bob()
        public
        giveToken(BLAST_DEPOSIT, address(stETH), alice, 200 ether)
        withCaller(alice)
    {
        uint256 stETHAmount = 100 ether;
        // Create an unsigned permit to call function
        Permit memory unsignedPermit = Permit(0, stETHAmount, 0, 0, 0);
        IERC20(address(stETH)).approve(address(pufferDepositor), stETHAmount);

        uint256 depositorAmount = pufferDepositor.depositStETH(unsignedPermit, bob);

        assertEq(depositorAmount, pufferVault.balanceOf(bob), "bob got the tokens");
        assertEq(0, pufferVault.balanceOf(alice), "alice got 0");
    }

    // wstETH permit deposit
    function test_wstETH_permit_deposit()
        public
        giveToken(0x0B925eD163218f6662a35e0f0371Ac234f9E9371, address(_WST_ETH), alice, 1 ether)
        withCaller(alice)
    {
        Permit memory permit = _signPermit(
            _testTemps(
                "alice",
                address(pufferDepositor),
                1 ether,
                block.timestamp,
                hex"d4a8ff90a402dc7d4fcbf60f5488291263c743ccff180e139f47d139cedfd5fe"
            )
        );
        uint256 received = pufferDepositor.depositWstETH(permit, alice);
        assertEq(received, pufferVault.balanceOf(alice), "alice got 0");
    }

    // wstETH permit deposit to bob
    function test_wstETH_permit_deposit_to_bob()
        public
        giveToken(0x0B925eD163218f6662a35e0f0371Ac234f9E9371, address(_WST_ETH), alice, 1 ether)
        withCaller(alice)
    {
        Permit memory permit = _signPermit(
            _testTemps(
                "alice",
                address(pufferDepositor),
                1 ether,
                block.timestamp,
                hex"d4a8ff90a402dc7d4fcbf60f5488291263c743ccff180e139f47d139cedfd5fe"
            )
        );
        uint256 received = pufferDepositor.depositWstETH(permit, bob);

        assertEq(received, pufferVault.balanceOf(bob), "bob got the tokens");
        assertEq(0, pufferVault.balanceOf(alice), "alice got 0");
    }

    // wstETH approve deposit
    function test_wstETH_approve_deposit_to_self()
        public
        giveToken(0x0B925eD163218f6662a35e0f0371Ac234f9E9371, address(_WST_ETH), alice, 1 ether)
        withCaller(alice)
    {
        // Create an unsigned permit to call function
        Permit memory unsignedPermit = Permit(0, 1 ether, 0, 0, 0);
        IERC20(address(_WST_ETH)).approve(address(pufferDepositor), 1 ether);
        uint256 received = pufferDepositor.depositWstETH(unsignedPermit, alice);

        assertEq(received, pufferVault.balanceOf(alice), "alice got the tokens");
    }

    // wstETH approve deposit to bob
    function test_wstETH_approve_deposit_to_bob()
        public
        giveToken(0x0B925eD163218f6662a35e0f0371Ac234f9E9371, address(_WST_ETH), alice, 1 ether)
        withCaller(alice)
    {
        // Create an unsigned permit to call function
        Permit memory unsignedPermit = Permit(0, 1 ether, 0, 0, 0);
        IERC20(address(_WST_ETH)).approve(address(pufferDepositor), 1 ether);
        uint256 received = pufferDepositor.depositWstETH(unsignedPermit, bob);

        assertEq(received, pufferVault.balanceOf(bob), "bob got the tokens");
        assertEq(0, pufferVault.balanceOf(alice), "alice got 0");
    }
}
