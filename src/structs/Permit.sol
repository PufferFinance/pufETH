// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

/**
 * @dev Struct representing a permit for a specific action.
 */
struct Permit {
    uint256 deadline;
    uint256 amount;
    uint8 v;
    bytes32 r;
    bytes32 s;
}
