// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { TestHelper } from "../TestHelper.sol";
import { Permit } from "../../src/structs/Permit.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

contract PufferDepositorV2MainnetForkTest is TestHelper {
    // StETH deposit through depositor and directly should mint the same amount
    function test_stETH_permit_deposit()
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
        uint256 depositorAmount = pufferDepositor.depositStETH(permit, alice);

        stETH.approve(address(pufferVault), 100 ether);
        uint256 directDepositAmount = pufferVault.depositStETH(100 ether, alice);

        assertEq(depositorAmount, directDepositAmount, "received amounts should be the same");
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
    function test_stETH_approve_deposit()
        public
        giveToken(BLAST_DEPOSIT, address(stETH), alice, 200 ether)
        withCaller(alice)
    {
        // Create an unsigned permit to call function
        Permit memory unsignedPermit = Permit(0, 100 ether, 0, 0, 0);
        IERC20(address(stETH)).approve(address(pufferDepositor), 100 ether);

        uint256 depositorAmount = pufferDepositor.depositStETH(unsignedPermit, alice);

        assertEq(depositorAmount, pufferVault.balanceOf(alice), "alice got the tokens");

        // StETH deposit through depositor and directly should mint the same amount
        stETH.approve(address(pufferVault), 100 ether);
        uint256 directDepositAmount = pufferVault.depositStETH(100 ether, alice);

        assertEq(depositorAmount, directDepositAmount, "received amounts should be the same");
    }

    // stETH approve deposit to bob
    function test_stETH_approve_deposit_to_bob()
        public
        giveToken(BLAST_DEPOSIT, address(stETH), alice, 200 ether)
        withCaller(alice)
    {
        // Create an unsigned permit to call function
        Permit memory unsignedPermit = Permit(0, 100 ether, 0, 0, 0);
        IERC20(address(stETH)).approve(address(pufferDepositor), 100 ether);

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

        assertEq(received, 1.155550410231651161 ether, "received amount");
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

        assertEq(received, 1.155550410231651161 ether, "received amount");
        assertEq(received, pufferVault.balanceOf(bob), "bob got the tokens");
        assertEq(0, pufferVault.balanceOf(alice), "alice got 0");
    }

    // wstETH approve deposit
    function test_wstETH_approve_deposit()
        public
        giveToken(0x0B925eD163218f6662a35e0f0371Ac234f9E9371, address(_WST_ETH), alice, 1 ether)
        withCaller(alice)
    {
        // Create an unsigned permit to call function
        Permit memory unsignedPermit = Permit(0, 1 ether, 0, 0, 0);
        IERC20(address(_WST_ETH)).approve(address(pufferDepositor), 1 ether);
        uint256 received = pufferDepositor.depositWstETH(unsignedPermit, alice);

        assertEq(received, 1.155550410231651161 ether, "received amount");
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

        assertEq(received, 1.155550410231651161 ether, "received amount");
        assertEq(received, pufferVault.balanceOf(bob), "bob got the tokens");
        assertEq(0, pufferVault.balanceOf(alice), "alice got 0");
    }
}
