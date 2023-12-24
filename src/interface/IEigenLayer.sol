// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

interface IEigenLayer {
    function depositStETH(uint256 _stETHAmount) external returns (uint256);
}