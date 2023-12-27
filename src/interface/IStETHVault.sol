// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

interface IStETHVault {
    // Deposit stETH for EigenPoints
    function depositToEigenLayer(uint256 amount) external returns (uint256);

    // Start withdrawing stETH from EigenLayer
    function queueWithdrawalFromEigenLayer(uint256 shares) external returns (bytes32);

    // Complete withdrawing stETH from EigenLayer
    function completeWithdrawalFromEigenLayer(uint256 shares) external;
}
