// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

interface IStrategy {
    /**
     * @notice Returns the amount of underlying tokens for `user`
     */
    function userUnderlying(address user) external view returns (uint256);
}
