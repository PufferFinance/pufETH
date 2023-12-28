// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

/**
 * @notice Sushiswap Router
 */
interface ISushiRouter {
    function processRoute(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 amountOutMin,
        address to,
        bytes memory route
    ) external returns (uint256 amountOut);
}
