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
     * @notice Thrown if Guardians try to re-submit the backing data
     * @dev Signature "0xf93417f7"
     */
    error OutsideUpdateWindow();

    /**
     * @notice Emitted when the Guardians update state of the protocol
     * @dev Signature "0xaabc7a8108435a4fc30d1e2cecd59cbdec96ee6fa583c6eebf9a20bc9d14d3ed"
     * @param blockNumber is the block number of the update
     * @param lockedETH is the locked ETH amount in Beacon chain
     */
    event ReservesUpdated(uint256 blockNumber, uint256 lockedETH, uint256 numberOfActivePufferValidators, uint256 totalNumberOfValidators);

    /**
     * @notice Returns the total number of active validators on Ethereum
     */
    function getTotalNumberOfValidators() external view returns (uint256);

    /**
     * @notice Returns the block number of the last update
     */
    function getLastUpdate() external view returns (uint256);

    /**
     * @notice Increases the `_lockedETH` amount on the Oracle by 32 ETH
     * It is called when the Beacon chain receives a new deposit from PufferProtocol
     * The PufferVault balance is decreased by the same amount
     * @dev Restricted to PufferProtocol contract
     */
    function provisionNode() external;
}
