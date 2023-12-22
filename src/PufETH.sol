// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { ERC20Permit } from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";

interface IPufETH is IERC20 {
    // Deposit stETH without swapping
    function depositStETH(uint256 amount) external returns (uint256);

    // Performs Swap from ETH to stETH
    function depositETH(uint256 amount) external returns (uint256);

    // Performs Swap from USDC to stETH
    function depositUSDC(uint256 amount) external returns (uint256);

    // Performs Swap from USDC to stETH
    function depositUSDT(uint256 amount) external returns (uint256);

    // Deposit stETH for EigenPoints
    function depositToEigenLayer(uint256 amount) external returns (uint256);

    // Retrieve stETH from EigenLayer
    function withdrawFromEigenLayer(uint256 amount) external returns (uint256);

    // Trigger redemptions from Lido
    function withdrawStETHToETH(uint256 amount) external returns (uint256);
}

contract PufETH is IPufETH {
    // Deposit stETH without swapping
    function depositStETH(uint256 amount) external returns (uint256) {
        return 1;
    }

    // Performs Swap from ETH to stETH
    function depositETH(uint256 amount) external returns (uint256) {
        return 1;
    }

    // Performs Swap from USDC to stETH
    function depositUSDC(uint256 amount) external returns (uint256) {
        return 1;
    }

    // Performs Swap from USDC to stETH
    function depositUSDT(uint256 amount) external returns (uint256) {
        return 1;
    }

    // Deposit stETH for EigenPoints
    function depositToEigenLayer(uint256 amount) external returns (uint256) {
        return 1;
    }

    // Retrieve stETH from EigenLayer
    function withdrawFromEigenLayer(uint256 amount) external returns (uint256) {
        return 1;
    }

    // Trigger redemptions from Lido
    function withdrawStETHToETH(uint256 amount) external returns (uint256) {
        return 1;
    } 
}