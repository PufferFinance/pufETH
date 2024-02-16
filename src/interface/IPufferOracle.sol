// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title IPufferOracle
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
interface IPufferOracle {
    /**
     * @notice Thrown if Guardians try to re-submit the backing data
     * @dev Signature "0xf93417f7"
     */
    error OutsideUpdateWindow();

    /**
     * @notice Emitted when the Guardians update state of the protocol
     * @param blockNumber is the block number of the update
     * @param lockedETH is the locked ETH amount in Beacon chain
     */
    event BackingUpdated(uint256 indexed blockNumber, uint256 lockedETH);

    /**
     * @notice Emitted when the price to mint VT is updated
     */
    event ValidatorTicketMintPriceUpdated(uint256 oldPrice, uint256 newPrice);

    /**
     * @notice Increases the `lockedETH` amount on the Oracle by 32 ETH
     * It is called when the Beacon chain receives a new deposit from PufferProtocol
     * The PufferVault balance is decreased by the same amount
     */
    function provisionNode() external;

    /**
     * @notice Retrieves the current mint price for minting one Validator Ticket
     * @return pricePerVT The current mint price
     */
    function getValidatorTicketPrice() external view returns (uint256 pricePerVT);

    /**
     * @notice Returns the locked ETH amount
     * @return lockedEthAmount The amount of ETH locked in Beacon chain
     */
    function getLockedEthAmount() external view returns (uint256 lockedEthAmount);

    /**
     * @notice Returns true if the number of active Puffer Validators is over the burst threshold
     */
    function isOverBurstThreshold() external view returns (bool);
}
