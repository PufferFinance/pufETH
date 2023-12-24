// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
interface IPufferPool is IERC20 {
    /**
     * @notice Deposits ETH and `msg.sender` receives pufETH in return
     * @return pufETH amount minted
     * @dev Signature "0xf6326fb3"
     */
    function depositETH() external payable returns (uint256);

    /**
     * @notice Calculates the equivalent pufETH amount for a given `amount` of ETH based on the current ETH:pufETH exchange rate
     * Suppose that the exchange rate is 1 : 1.05 and the user is wondering how much `pufETH` will he receive if he deposits `amount` ETH.
     *
     * outputAmount = amount * (1 / exchangeRate) // because the exchange rate is 1 to 1.05
     * outputAmount = amount * (1 / 1.05)
     * outputAmount = amount * 0.95238095238
     *
     * if the user is depositing 1 ETH, he would get 0.95238095238 pufETH in return
     *
     * @param amount The amount of ETH to be converted to pufETH
     * @dev Signature "0x1b5ebe05"
     * @return The equivalent amount of pufETH
     */
    function calculateETHToPufETHAmount(
        uint256 amount
    ) external view returns (uint256);

    /**
     * @notice Calculates the equivalent ETH amount for a given `pufETHAmount` based on the current ETH:pufETH exchange rate
     *
     * Suppose that the exchange rate is 1 : 1.05 and the user is wondering how much `pufETH` will he receive if he wants to redeem `pufETHAmount` worth of pufETH.
     *
     * outputAmount = pufETHAmount * (1.05 / 1) // because the exchange rate is 1 to 1.05 (ETH to pufETH)
     * outputAmount = pufETHAmount * 1.05
     *
     * if the user is redeeming 1 pufETH, he would get 1.05 ETH in return
     *
     * NOTE: The calculation does not take in the account any withdrawal fee.
     *
     * @param pufETHAmount The amount of pufETH to be converted to ETH
     * @dev Signature "0x149a74ed"
     * @return The equivalent amount of ETH
     */
    function calculatePufETHtoETHAmount(
        uint256 pufETHAmount
    ) external view returns (uint256);
}