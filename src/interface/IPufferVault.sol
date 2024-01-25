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
     * @notice Emitted stETH is deposited with referral
     */
    event DepositedWithReferral(address indexed receiver, uint256 amount, address indexed referral);

    /**
     * @notice Emitted when the user tries to do a withdrawal
     */
    error WithdrawalsAreDisabled();

    /**
     * @notice Deposits assets with a referral
     * @param assets The amount of assets to deposit
     * @param receiver The address to receive the deposit
     * @param referral The address of the referral
     * @return The amount of shares minted `pufETH`
     */
    function depositWithReferral(uint256 assets, address receiver, address referral) external returns (uint256);
}
