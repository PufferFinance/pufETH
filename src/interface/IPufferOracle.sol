// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title IPufferOracle
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
interface IPufferOracle {
    function getLockedEthAmount() external view returns (uint256 lockedEthAmount);
}