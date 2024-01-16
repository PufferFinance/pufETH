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
     * @notice Emitted when we deposit stETH to EigenLayer
     */
    event DepositedToEigenLayer(uint256 amount);
    /**
     * @notice Emitted when we initiate withdrawal from EigenLayer
     */
    event InitiatedWithdrawalFromEigenLayer(uint256 elSharesAmount);
    /**
     * @notice Emitted when we claim the queued withdrawal from EigenLayer
     */
    event ClaimedWithdrawalFromEigenLayer(uint256 elSharesAmount);

    /**
     * @notice Emitted when the user tries to do a withdrawal
     */
    error WithdrawalsAreDisabled();
}
