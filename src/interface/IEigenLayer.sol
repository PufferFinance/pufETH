// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

interface IStrategy {
    /**
     * @notice Returns the total number of shares in the EL Strategy
     */
    function totalShares() external view returns (uint256);
}

// packed struct for queued withdrawals; helps deal with stack-too-deep errors
struct WithdrawerAndNonce {
    address withdrawer;
    uint96 nonce;
}

/**
 * Struct type used to specify an existing queued withdrawal. Rather than storing the entire struct, only a hash is stored.
 * In functions that operate on existing queued withdrawals -- e.g. `startQueuedWithdrawalWaitingPeriod` or `completeQueuedWithdrawal`,
 * the data is resubmitted and the hash of the submitted data is computed by `calculateWithdrawalRoot` and checked against the
 * stored hash in order to confirm the integrity of the submitted data.
 */
struct QueuedWithdrawal {
    IStrategy[] strategies;
    uint256[] shares;
    address depositor;
    WithdrawerAndNonce withdrawerAndNonce;
    uint32 withdrawalStartBlock;
    address delegatedAddress;
}

interface IEigenLayer {
    function depositIntoStrategy(IStrategy strategy, IERC20 token, uint256 amount) external returns (uint256 shares);

    /**
     * @notice Returns the Strategy deposits for `staker` (EigenStrategyManager)
     */
    function getDeposits(address staker) external view returns (IStrategy[] memory, uint256[] memory);

    function queueWithdrawal(
        uint256[] calldata strategyIndexes,
        IStrategy[] calldata strategies,
        uint256[] calldata shares,
        address withdrawer,
        bool undelegateIfPossible
    ) external returns (bytes32);

    function completeQueuedWithdrawal(
        QueuedWithdrawal calldata queuedWithdrawal,
        IERC20[] calldata tokens,
        uint256 middlewareTimesIndex,
        bool receiveAsTokens
    ) external;
}
