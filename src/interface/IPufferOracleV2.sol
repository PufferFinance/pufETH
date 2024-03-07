// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { IPufferOracle } from "./IPufferOracle.sol";

/**
 * @title IPufferOracle
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
interface IPufferOracleV2 is IPufferOracle {
    /**
     * @notice Emitted when the number of active Puffer validators is updated
     * @param numberOfActivePufferValidators is the number of active Puffer validators
     */
    event NumberOfActiveValidators(uint256 numberOfActivePufferValidators);

    /**
     * @notice Returns the total number of active validators on Ethereum
     */
    function getTotalNumberOfValidators() external view returns (uint256);

    /**
     * @notice Exits the validator, decreasing the `lockedETHAmount` by 32 ETH.
     * It is called when when the Node Operator triggers the `retrieveBond` on the PufferProtocol.
     * In the same transaction, we are transferring full withdrawal ETH from the PufferModule to the Vault
     * Decrementing the `lockedETHAmount` by 32 ETH and we burn the Node Operator's pufETH (bond) if we need to cover up the loss.
     * @dev Restricted to PufferProtocol contract
     */
    function exitValidator() external;

    /**
     * @notice Increases the `lockedETHAmount` on the PufferOracle by 32 ETH to account for a new deposit.
     * It is called when the Beacon chain receives a new deposit from the PufferProtocol.
     * The PufferVault's balance will simultaneously decrease by 32 ETH as the deposit is made.
     * @dev Restricted to PufferProtocol contract
     */
    function provisionNode() external;
}
