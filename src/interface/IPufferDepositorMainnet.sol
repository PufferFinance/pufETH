// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { Permit } from "../structs/Permit.sol";

/**
 * @title PufferDepositor
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
interface IPufferDepositorMainnet {
    /**
     * @notice Deposits wrapped stETH (wstETH) into the Puffer Vault
     * @param permitData The permit data containing the approval information
     * @param recipient The recipient of pufETH tokens
     * @return pufETHAmount The amount of pufETH received from the deposit
     */
    function depositWstETH(Permit calldata permitData, address recipient) external returns (uint256 pufETHAmount);

    /**
     * @notice Deposits stETH into the Puffer Vault using Permit
     * @param permitData The permit data containing the approval information
     * @param recipient The recipient of pufETH tokens
     * @return pufETHAmount The amount of pufETH received from the deposit
     */
    function depositStETH(Permit calldata permitData, address recipient) external returns (uint256 pufETHAmount);
}
