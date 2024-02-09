// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { IStrategy } from "src/interface/EigenLayer/IStrategy.sol";

contract stETHStrategyMock is IStrategy {
    /**
     * @notice Returns the amount of underlying tokens for `user`
     */
    function userUnderlying(address user) external view returns (uint256) { }

    function userUnderlyingView(address user) external view returns (uint256) { }

    function sharesToUnderlyingView(uint256 amountShares) external view returns (uint256) { }
}
