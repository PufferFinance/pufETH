// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";

/**
 * @title Timelock
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
contract Timelock {
    /**
     * @notice Error to be thrown when a bad address is encountered
     */
    error BadAddress();
    /**
     * @notice Error to be thrown when an invalid delay is encountered
     */
    error InvalidDelay(uint256 delay);
    /**
     * @notice Error to be thrown when an unauthorized action is attempted
     */
    error Unauthorized();
    /**
     * @notice Error to be thrown when an invalid transaction is attempted
     * @param txHash The keccak256 hash of the invalid transaction
     */
    error InvalidTransaction(bytes32 txHash);
    /**
     * @notice Error to be thrown when a transaction is attempted before the lock period expires
     * @param txHash The keccak256 hash of the locked transaction
     * @param lockedUntil The timestamp when the transaction can be executed
     */
    error Locked(bytes32 txHash, uint256 lockedUntil);

    /**
     * @notice Emitted when the delay changes from `oldDelay` to `newDelay`
     */
    event DelayChanged(uint256 oldDelay, uint256 newDelay);
    /**
     * @notice Emitted when a transaction is queued
     * @param txHash The keccak256 hash of the queued transaction
     * @param target The address to which the transaction will be sent
     * @param callData The data to be sent along with the transaction
     * @param lockedUntil The timestamp when the transaction can be executed
     */
    event TransactionQueued(bytes32 indexed txHash, address indexed target, bytes callData, uint256 lockedUntil);
    /**
     * @notice Emitted when a transaction is canceled
     * @param txHash The keccak256 hash of the canceled transaction
     * @param target The address to which the transaction was to be sent
     * @param callData The data that was to be sent along with the transaction
     */
    event TransactionCanceled(bytes32 indexed txHash, address indexed target, bytes callData);
    /**
     * @notice Emitted when a transaction is executed
     * @param txHash The keccak256 hash of the executed transaction
     * @param target The address to which the transaction was sent
     * @param callData The data that was sent along with the transaction
     */
    event TransactionExecuted(bytes32 indexed txHash, address indexed target, bytes callData);

    /**
     * @notice Community multisig has 0 delay
     */
    address public immutable COMMUNITY_MULTISIG;
    /**
     * @notice Operations multisig has a variable delay
     */
    address public immutable OPERATIONS_MULTISIG;
    /**
     * @notice Can only pause the system
     */
    address public immutable PAUSER_MULTISIG;
    /**
     * @notice AccessManager
     */
    AccessManager public immutable ACCESS_MANAGER;
    /**
     * @notice Minimum delay enforced by the contract
     */
    uint256 public constant MINIMUM_DELAY = 2 days;

    /**
     * @notice Timelock delay in seconds
     */
    uint256 public delay;
    /**
     * @notice Transaction queue
     */
    mapping(bytes32 transactionHash => uint256 lockedUntil) public queue;

    constructor(
        address communityMultisig,
        address operationsMultisig,
        address pauserMultisig,
        address accessManager,
        uint256 initialDelay
    ) {
        _validateAddress(communityMultisig);
        _validateAddress(operationsMultisig);
        _validateAddress(pauserMultisig);
        _validateAddress(accessManager);
        COMMUNITY_MULTISIG = communityMultisig;
        OPERATIONS_MULTISIG = operationsMultisig;
        PAUSER_MULTISIG = pauserMultisig;
        ACCESS_MANAGER = AccessManager(accessManager);
        _setDelay(initialDelay);
    }

    /**
     * @notice Operations multisig queues a transaction that can be executed by the operations multisig after the delay period
     * @param target The address to which the transaction will be sent
     * @param callData The data to be sent along with the transaction
     * @return The keccak256 hash of the queued transaction
     */
    function queueTransaction(address target, bytes memory callData) public returns (bytes32) {
        if (msg.sender != OPERATIONS_MULTISIG) {
            revert Unauthorized();
        }

        bytes32 txHash = keccak256(abi.encode(target, callData));
        uint256 lockedUntil = block.timestamp + delay;
        queue[txHash] = lockedUntil;

        emit TransactionQueued(txHash, target, callData, lockedUntil);

        return txHash;
    }

    /**
     * @notice Pauses the system by closing access to specified targets
     * @param targets An array of addresses to which access will be paused
     */
    function pause(address[] calldata targets) public {
        // Community multisig can call this by via executeTransaction
        if (msg.sender != PAUSER_MULTISIG && msg.sender != address(this)) {
            revert Unauthorized();
        }

        bytes[] memory callDatas = new bytes[](targets.length);

        for (uint256 i = 0; i < targets.length; ++i) {
            callDatas[i] = abi.encodeCall(AccessManager.setTargetClosed, (targets[i], true));
        }

        ACCESS_MANAGER.multicall(callDatas);
    }

    /**
     * @notice Cancels a queued transaction
     * @param target The address to which the transaction was to be sent
     * @param callData The data that was to be sent along with the transaction
     */
    function cancelTransaction(address target, bytes memory callData) public {
        // Community multisig can call this by via executeTransaction
        if (msg.sender != OPERATIONS_MULTISIG && msg.sender != address(this)) {
            revert Unauthorized();
        }

        bytes32 txHash = keccak256(abi.encode(target, callData));
        queue[txHash] = 0;

        emit TransactionCanceled(txHash, target, callData);
    }

    /**
     * @notice Executes a transaction after the delay period for Operations Multisig
     * Community multisig can execute transactions without any delay
     * @param target The address to which the transaction will be sent
     * @param callData The data to be sent along with the transaction
     * @return success A boolean indicating whether the transaction was successful
     * @return returnData The data returned by the transaction
     */
    function executeTransaction(address target, bytes calldata callData)
        external
        returns (bool success, bytes memory returnData)
    {
        // Community Multisig can do things without any delay
        if (msg.sender == COMMUNITY_MULTISIG) {
            return _executeTransaction(target, callData);
        }

        // Operations multisig needs to queue it and then execute after a delay
        if (msg.sender != OPERATIONS_MULTISIG) {
            revert Unauthorized();
        }

        bytes32 txHash = keccak256(abi.encode(target, callData));
        uint256 lockedUntil = queue[txHash];

        // slither-disable-next-line incorrect-equality
        if (lockedUntil == 0) {
            revert InvalidTransaction(txHash);
        }

        if (block.timestamp < lockedUntil) {
            revert Locked(txHash, lockedUntil);
        }

        queue[txHash] = 0;
        (success, returnData) = _executeTransaction(target, callData);

        emit TransactionExecuted(txHash, target, callData);

        return (success, returnData);
    }

    /**
     * @notice Sets a new delay for the timelock
     * @param newDelay The new delay in seconds
     */
    function setDelay(uint256 newDelay) public {
        if (msg.sender != address(this)) {
            revert Unauthorized();
        }
        _setDelay(newDelay);
    }

    function _setDelay(uint256 newDelay) internal {
        if (newDelay <= MINIMUM_DELAY) {
            revert InvalidDelay(newDelay);
        }
        emit DelayChanged(delay, newDelay);
        delay = newDelay;
    }

    function _executeTransaction(address target, bytes calldata callData) internal returns (bool, bytes memory) {
        // slither-disable-next-line arbitrary-send-eth
        return target.call(callData);
    }

    function _validateAddress(address input) internal pure {
        if (input == address(0)) {
            revert BadAddress();
        }
    }
}
