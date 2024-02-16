// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title PufferDepositor
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
interface IPufferDepositorMainnet {
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

    /**
     * @notice Deposits wrapped stETH (wstETH) into the Puffer Vault
     * @param permitData The permit data containing the approval information
     * @return pufETHAmount The amount of pufETH received from the deposit
     */
    function depositWstETH(IPufferDepositorMainnet.Permit calldata permitData)
        external
        returns (uint256 pufETHAmount);

    /**
     * @notice Deposits stETH into the Puffer Vault using Permit
     * @param permitData The permit data containing the approval information
     * @return pufETHAmount The amount of pufETH received from the deposit
     */
    function depositStETH(IPufferDepositorMainnet.Permit calldata permitData) external returns (uint256 pufETHAmount);
}
