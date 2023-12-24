// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

interface IWithdrawalPool {
    /**
     * @notice Burns `pufETHAmount` and sends the ETH to `to`
     * @dev You need to approve `pufETHAmount` to this contract by calling pool.approve
     * @return ETH Amount redeemed
     */
    function withdrawETH(
        address to,
        uint256 pufETHAmount
    ) external returns (uint256);
}