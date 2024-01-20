// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

/**
 * @title PufferDepositor
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
interface IPufferDepositor {
    /**
     * @dev Error indicating that the token is not allowed.
     */
    error TokenNotAllowed(address token);

    /**
     * @dev Event indicating that the token is allowed.
     */
    event TokenAllowed(IERC20 token);
    /**
     * @dev Event indicating that the token is disallowed.
     */
    event TokenDisallowed(IERC20 token);

    /**
     * @dev Struct representing a permit for a specific action.
     */
    struct Permit {
        address owner;
        uint256 deadline;
        uint256 amount;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    /**
     * @notice Swaps `amountIn` of `tokenIn` for stETH and deposits it into the Puffer Vault
     * @param tokenIn The address of the token being swapped
     * @param amountIn The amount of `tokenIn` to swap
     * @param amountOutMin The minimum amount of stETH to receive from the swap
     * @param routeCode The encoded route for the swap
     * @return pufETHAmount The amount of pufETH received from the deposit
     */
    function swapAndDeposit(address tokenIn, uint256 amountIn, uint256 amountOutMin, bytes calldata routeCode)
        external
        returns (uint256 pufETHAmount);

    /**
     * @notice Swaps `permitData.amount` of `tokenIn` for stETH using a permit and deposits it into the Puffer Vault
     * @param tokenIn The address of the token being swapped
     * @param amountOutMin The minimum amount of stETH to receive from the swap
     * @param permitData The permit data containing the approval information
     * @param routeCode The encoded route for the swap
     * @return pufETHAmount The amount of pufETH received from the deposit
     */
    function swapAndDepositWithPermit(
        address tokenIn,
        uint256 amountOutMin,
        IPufferDepositor.Permit calldata permitData,
        bytes calldata routeCode
    ) external returns (uint256 pufETHAmount);

    /**
     * @notice Deposits wrapped stETH (wstETH) into the Puffer Vault
     * @param permitData The permit data containing the approval information
     * @return pufETHAmount The amount of pufETH received from the deposit
     */
    function depositWstETH(IPufferDepositor.Permit calldata permitData) external returns (uint256 pufETHAmount);
}
