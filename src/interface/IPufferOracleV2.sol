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
     * @notice Thrown if proof-of-reserves is submitted outside of the acceptable window
     * @dev Signature "0xf93417f7"
     */
    error OutsideUpdateWindow();

    /**
     * @notice Emitted when the proof-of-reserves updates the PufferVault's state
     * @dev Signature "0xaabc7a8108435a4fc30d1e2cecd59cbdec96ee6fa583c6eebf9a20bc9d14d3ed"
     * @param blockNumber is the block number of the proof-of-reserves update
     * @param lockedETH is the validator ETH locked in the Beacon chain
     * @param numberOfActivePufferValidators is the number of active Puffer validators, used in enforcing the burst threshold
     * @param totalNumberOfValidators is the total number of active validators on Ethereum, used in enforcing the burst threshold
     */
    event ReservesUpdated(
        uint256 blockNumber, uint256 lockedETH, uint256 numberOfActivePufferValidators, uint256 totalNumberOfValidators
    );

    /**
     * @notice Returns the total number of active validators on Ethereum
     */
    function getTotalNumberOfValidators() external view returns (uint256);

    /**
     * @notice Returns the block number of the last proof-of-reserves update
     */
    function getLastUpdate() external view returns (uint256);

    /**
     * @notice Increases the `_lockedETH` variable on the PufferOracle by 32 ETH to account for a new deposit. 
     * It is called when the Beacon chain receives a new deposit from the PufferProtocol.
     * The PufferVault's balance will simultaneously decrease by 32 ETH as the deposit is made.
     * The purpose is to keep the PufferVault totalAssets amount in sync between proof-of-reserves updates.
     * @dev Restricted to PufferProtocol contract
     */
    function provisionNode() external;
}
