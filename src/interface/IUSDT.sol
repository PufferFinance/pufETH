// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

interface IUSDT {
    function transfer(address to, uint256 amount) external;

    function transferFrom(address from, address to, uint256 amount) external;

    function approve(address spender, uint256 amount) external;

    function basisPointsRate() external view returns (uint256);

    function balanceOf(address) external view returns (uint256);
}
