// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title PufferVault
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
interface IPufferVault {
    /**
     * @notice Emitted when we request withdrawals from Lido
     */
    event RequestedWithdrawals(uint256[] requestIds);
    /**
     * @notice Emitted when we claim the withdrawals from Lido
     */
    event ClaimedWithdrawals(uint256[] requestIds);
    /**
     * @notice Emitted when the user tries to do a withdrawal
     */

    /**
     * @dev Thrown when withdrawals are disabled and a withdrawal attempt is made
     */
    error WithdrawalsAreDisabled();

    /**
     * @dev Thrown when a withdrawal attempt is made with invalid parameters
     */
    error InvalidWithdrawal();
}
