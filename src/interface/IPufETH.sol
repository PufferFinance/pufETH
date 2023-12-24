// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

interface IPufETH is IERC20 {
    // Deposit stETH without swapping
    function depositStETH(uint256 _stETHAmount) external returns (uint256);

    // Performs Swap from ETH to stETH
    function depositETH(uint256 _ETHAmount) external returns (uint256);

    // Performs Swap from USDC to stETH
    function depositUSDC(uint256 _USDCAmount) external returns (uint256);

    // Performs Swap from USDC to stETH
    function depositUSDT(uint256 _USDTAmount) external returns (uint256);

    // Deposit stETH for EigenPoints
    function depositToEigenLayer(
        uint256 _stETHAmount
    ) external returns (uint256);

    // Retrieve stETH from EigenLayer
    function withdrawFromEigenLayer(
        uint256 _stETHAmount
    ) external returns (uint256);

    // Trigger redemptions from Lido
    function withdrawStETHToETH(
        uint256 _stETHAmount
    ) external returns (uint256);
}