// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

interface IXERC20Lockbox {
    /**
     * @notice Emitted when tokens are deposited into the lockbox
     *
     * @param sender The address of the user who deposited
     * @param amount The amount of tokens deposited
     */
    event Deposit(address sender, uint256 amount);

    /**
     * @notice Emitted when tokens are withdrawn from the lockbox
     *
     * @param sender The address of the user who withdrew
     * @param amount The amount of tokens withdrawn
     */
    event Withdraw(address sender, uint256 amount);

    /**
     * @notice Reverts when a user tries to deposit native tokens on a non-native lockbox
     */
    error IXERC20Lockbox_NotNative();

    /**
     * @notice Deposit ERC20 tokens into the lockbox
     *
     * @param amount The amount of tokens to deposit
     */
    function deposit(uint256 amount) external;

    /**
     * @notice Deposit ERC20 tokens into the lockbox, and send the XERC20 to a user
     *
     * @param user The user to send the XERC20 to
     * @param amount The amount of tokens to deposit
     */
    function depositTo(address user, uint256 amount) external;

    /**
     * @notice Deposit the native asset into the lockbox, and send the XERC20 to a user
     *
     * @param user The user to send the XERC20 to
     */
    function depositNativeTo(address user) external payable;

    /**
     * @notice Withdraw ERC20 tokens from the lockbox
     *
     * @param amount The amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external;

    /**
     * @notice Withdraw ERC20 tokens from the lockbox
     *
     * @param user The user to withdraw to
     * @param amount The amount of tokens to withdraw
     */
    function withdrawTo(address user, uint256 amount) external;
}
