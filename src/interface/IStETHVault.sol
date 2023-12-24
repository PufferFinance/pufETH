// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

interface IStETHVault {
    // Deposit stETH for EigenPoints
    function depositToEigenLayer(uint256 amount) external returns (uint256);
}
