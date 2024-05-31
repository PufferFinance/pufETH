// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { PufferDepositor } from "src/PufferDepositor.sol";
import { Timelock } from "src/Timelock.sol";
import { PufferVault } from "src/PufferVault.sol";
import { stETHMock } from "test/mocks/stETHMock.sol";
import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";
import { PufferDeployment } from "src/structs/PufferDeployment.sol";
import { DeployPufETH } from "script/DeployPufETH.s.sol";
import { UUPSUpgradeable } from "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract TimelockTest is Test {
    PufferDepositor public pufferDepositor;
    PufferVault public pufferVault;
    AccessManager public accessManager;
    stETHMock public stETH;
    Timelock public timelock;

    function setUp() public {
        PufferDeployment memory deployment = new DeployPufETH().run();

        pufferDepositor = PufferDepositor(payable(deployment.pufferDepositor));
        pufferVault = PufferVault(payable(deployment.pufferVault));
        accessManager = AccessManager(payable(deployment.accessManager));
        stETH = stETHMock(payable(deployment.stETH));
        timelock = Timelock(payable(deployment.timelock));
    }

    function test_initial_access_manager_setup(address caller) public {
        vm.assume(caller != timelock.COMMUNITY_MULTISIG());
        vm.assume(caller != timelock.OPERATIONS_MULTISIG());
        vm.assume(caller != address(timelock));

        (bool canCall, uint32 delay) =
            accessManager.canCall(caller, address(pufferVault), PufferVault.initiateETHWithdrawalsFromLido.selector);
        assertFalse(canCall, "should not be able to call");

        // Restricted to operations / community multisig
        (canCall, delay) = accessManager.canCall(caller, address(pufferVault), PufferVault.depositToEigenLayer.selector);
        assertFalse(canCall, "should not be able to call");

        (canCall, delay) = accessManager.canCall(
            caller, address(pufferVault), PufferVault.initiateStETHWithdrawalFromEigenLayer.selector
        );
        assertFalse(canCall, "should not be able to call");

        // Upgrades are forbidden
        (canCall, delay) =
            accessManager.canCall(caller, address(pufferVault), UUPSUpgradeable.upgradeToAndCall.selector);
        assertFalse(canCall, "should not be able to call");

        (canCall, delay) =
            accessManager.canCall(caller, address(pufferDepositor), UUPSUpgradeable.upgradeToAndCall.selector);
        assertFalse(canCall, "should not be able to call");

        // Public
        (canCall, delay) =
            accessManager.canCall(caller, address(pufferDepositor), PufferDepositor.swapAndDeposit.selector);
        assertTrue(canCall, "should be able to call");

        (canCall, delay) =
            accessManager.canCall(caller, address(pufferDepositor), PufferDepositor.swapAndDepositWithPermit.selector);
        assertTrue(canCall, "should be able to call");

        (canCall, delay) =
            accessManager.canCall(caller, address(pufferDepositor), PufferDepositor.depositWstETH.selector);
        assertTrue(canCall, "should be able to call");
    }

    function test_set_delay_queued() public {
        vm.startPrank(timelock.OPERATIONS_MULTISIG());

        bytes memory callData = abi.encodeCall(Timelock.setDelay, (15 days));

        assertTrue(timelock.delay() != 15 days, "initial delay");

        uint256 operationId = 1234;

        bytes32 txHash = timelock.queueTransaction(address(timelock), callData, operationId);

        uint256 lockedUntil = block.timestamp + timelock.delay();

        vm.expectRevert(abi.encodeWithSelector(Timelock.Locked.selector, txHash, lockedUntil));
        timelock.executeTransaction(address(timelock), callData, operationId);

        vm.warp(lockedUntil + 1);

        timelock.executeTransaction(address(timelock), callData, operationId);

        assertEq(timelock.delay(), 15 days, "updated the delay");
    }

    function test_queue_should_revert_if_operations_is_not_the_caller(address caller) public {
        vm.assume(caller != timelock.OPERATIONS_MULTISIG());

        bytes memory callData = abi.encodeCall(Timelock.setDelay, (15 days));
        vm.expectRevert(abi.encodeWithSelector(Timelock.Unauthorized.selector));
        timelock.queueTransaction(address(timelock), callData, 10);
    }

    function test_pause_should_revert_if_bad_caller(address caller) public {
        vm.assume(caller != timelock.pauserMultisig());
        vm.assume(caller != address(timelock));

        address[] memory targets = new address[](1);
        targets[0] = address(pufferDepositor);

        vm.expectRevert(abi.encodeWithSelector(Timelock.Unauthorized.selector));
        timelock.pause(targets);
    }

    function test_cancel_transaction() public {
        vm.startPrank(timelock.OPERATIONS_MULTISIG());

        bytes memory callData = abi.encodeCall(Timelock.setDelay, (15 days));

        uint256 operationId = 1234;

        bytes32 txHash = timelock.queueTransaction(address(timelock), callData, operationId);

        uint256 lockedUntil = block.timestamp + timelock.delay();

        assertTrue(timelock.queue(txHash) != 0, "queued");

        timelock.cancelTransaction(address(timelock), callData, operationId);

        assertEq(timelock.queue(txHash), 0, "canceled");

        vm.warp(lockedUntil + 1);

        vm.expectRevert(abi.encodeWithSelector(Timelock.InvalidTransaction.selector, txHash));
        timelock.executeTransaction(address(timelock), callData, operationId);

        vm.expectRevert(abi.encodeWithSelector(Timelock.InvalidTransaction.selector, txHash));
        timelock.cancelTransaction(address(timelock), callData, operationId);
    }

    function test_community_transaction() public {
        vm.startPrank(timelock.OPERATIONS_MULTISIG());

        bytes memory callData = abi.encodeCall(Timelock.setDelay, (15 days));

        uint256 operationId = 1234;

        bytes32 txHash = timelock.queueTransaction(address(timelock), callData, operationId);

        uint256 lockedUntil = block.timestamp + timelock.delay();

        assertTrue(timelock.queue(txHash) != 0, "queued");

        vm.startPrank(timelock.COMMUNITY_MULTISIG());
        timelock.executeTransaction(address(timelock), callData, operationId);

        assertEq(timelock.queue(txHash), 0, "executed");
        assertEq(timelock.delay(), 15 days, "updated the delay");
    }

    function test_cancel_reverts_if_caller_unauthorized(address caller) public {
        vm.assume(caller != timelock.OPERATIONS_MULTISIG());
        vm.assume(caller != address(timelock));

        vm.expectRevert(abi.encodeWithSelector(Timelock.Unauthorized.selector));
        timelock.cancelTransaction(address(timelock), "", 1);
    }

    function test_execute_reverts_if_caller_unauthorized(address caller) public {
        vm.assume(caller != timelock.OPERATIONS_MULTISIG());
        vm.assume(caller != address(timelock));

        vm.expectRevert(abi.encodeWithSelector(Timelock.Unauthorized.selector));
        timelock.executeTransaction(address(timelock), "", 1);
    }

    function test_setDelay_reverts_if_caller_unauthorized(address caller) public {
        vm.assume(caller != address(timelock));

        vm.expectRevert(abi.encodeWithSelector(Timelock.Unauthorized.selector));
        timelock.setDelay(500);
    }

    function test_setPauser_reverts_if_caller_unauthorized(address caller) public {
        vm.assume(caller != address(timelock));

        vm.expectRevert(abi.encodeWithSelector(Timelock.Unauthorized.selector));
        timelock.setPauser(address(50));
    }

    function test_update_delay_from_community_without_timelock() public {
        vm.startPrank(timelock.COMMUNITY_MULTISIG());

        assertTrue(timelock.delay() != 15 days, "initial delay");

        bytes memory callData = abi.encodeCall(Timelock.setDelay, (15 days));

        bytes memory tooSmallDelayCallData = abi.encodeCall(Timelock.setDelay, (1 days));

        uint256 operationId = 1234;

        // revert if the timelock is too small
        (bool success, bytes memory returnData) =
            timelock.executeTransaction(address(timelock), tooSmallDelayCallData, operationId);
        assertEq(returnData, abi.encodeWithSelector(Timelock.InvalidDelay.selector, 1 days), "return data should fail");
        assertFalse(success, "should fail");

        timelock.executeTransaction(address(timelock), callData, 1234);

        assertEq(timelock.delay(), 15 days, "updated the delay");
    }

    function test_queueing_duplicate_transaction_different_operation_id() public {
        vm.startPrank(timelock.OPERATIONS_MULTISIG());

        bytes memory callData = abi.encodeCall(Timelock.setDelay, (15 days));

        bytes32 expectedTx1Hash = keccak256(abi.encode(address(timelock), callData, 1234));
        bytes32 expectedTx2Hash = keccak256(abi.encode(address(timelock), callData, 3333));

        vm.expectEmit(true, true, true, true);
        emit Timelock.TransactionQueued(
            expectedTx1Hash, address(timelock), callData, 1234, block.timestamp + timelock.delay()
        );
        bytes32 txHash1 = timelock.queueTransaction(address(timelock), callData, 1234);

        vm.expectEmit(true, true, true, true);
        emit Timelock.TransactionQueued(
            expectedTx2Hash, address(timelock), callData, 3333, block.timestamp + timelock.delay()
        );
        bytes32 txHash2 = timelock.queueTransaction(address(timelock), callData, 3333);
        assertTrue(txHash1 != txHash2, "hashes must be different");
    }

    function test_pause_depositor(address caller) public {
        vm.startPrank(timelock.pauserMultisig());

        address[] memory targets = new address[](1);
        targets[0] = address(pufferDepositor);

        timelock.pause(targets);

        (bool canCall, uint32 delay) =
            accessManager.canCall(caller, address(pufferDepositor), PufferDepositor.swapAndDeposit.selector);
        assertTrue(!canCall, "should not be able to call");

        (canCall, delay) =
            accessManager.canCall(caller, address(pufferDepositor), PufferDepositor.swapAndDepositWithPermit.selector);
        assertTrue(!canCall, "should not be able to call");

        (canCall, delay) =
            accessManager.canCall(caller, address(pufferDepositor), PufferDepositor.depositWstETH.selector);
        assertTrue(!canCall, "should not be able to call");
    }

    function test_pause_depositor_slectors(address caller) public {
        vm.startPrank(timelock.pauserMultisig());
        vm.assume(caller != address(timelock));

        address[] memory targets = new address[](1);
        targets[0] = address(pufferDepositor);

        bytes4[][] memory selectors = new bytes4[][](1);
        selectors[0] = new bytes4[](1);

        selectors[0][0] = PufferDepositor.swapAndDeposit.selector;

        timelock.pauseSelectors(targets, selectors);

        (bool canCall, uint32 delay) =
            accessManager.canCall(caller, address(pufferDepositor), PufferDepositor.swapAndDeposit.selector);
        assertTrue(!canCall, "should not be able to call");

        (canCall, delay) =
            accessManager.canCall(caller, address(pufferDepositor), PufferDepositor.swapAndDepositWithPermit.selector);
        assertTrue(canCall, "should able to call");

        (canCall, delay) =
            accessManager.canCall(caller, address(pufferDepositor), PufferDepositor.depositWstETH.selector);
        assertTrue(canCall, "should be able to call");
    }

    function test_change_pauser() public {
        vm.startPrank(timelock.COMMUNITY_MULTISIG());

        address existingPauser = timelock.pauserMultisig();

        address newPauser = makeAddr("newPauser");

        bytes memory callData = abi.encodeCall(Timelock.setPauser, (newPauser));

        vm.expectEmit(true, true, true, true);
        emit Timelock.PauserChanged(existingPauser, newPauser);
        timelock.executeTransaction(address(timelock), callData, 1234);

        assertEq(newPauser, timelock.pauserMultisig(), "pauser did not change");
    }

    function test_execute_fails_due_to_gas() public {
        vm.startPrank(timelock.OPERATIONS_MULTISIG());

        bytes memory callData = abi.encodeCall(this.gasConsumingFunc, ());

        uint256 operationId = 1234;

        bytes32 txHash = timelock.queueTransaction(address(this), callData, operationId);

        uint256 lockedUntil = block.timestamp + timelock.delay();

        vm.warp(lockedUntil + 20);

        uint256 gasToUse = 214_640;

        vm.expectRevert(abi.encodeWithSelector(Timelock.ExecutionFailedAtTarget.selector));
        timelock.executeTransaction{ gas: gasToUse }(address(this), callData, operationId);
    }

    function gasConsumingFunc() external {
        uint256 gasToConsume = 209595;
        uint256 gasStart = gasleft();
        for (uint256 i = 0; gasStart - gasleft() < gasToConsume; i++) {
            assembly {
                let x := mload(0x1337)
            }
        }
    }
}
