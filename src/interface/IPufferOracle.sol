// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title IPufferOracle
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
interface IPufferOracle {
    /**
     * @notice Emitted when the price to mint VT is updated
     * @dev Signature "0xf76811fec27423d0853e6bf49d7ea78c666629c2f67e29647d689954021ae0ea"
     */
    event ValidatorTicketMintPriceUpdated(uint256 oldPrice, uint256 newPrice);

    /**
     * @notice Retrieves the current mint price for minting one Validator Ticket
     * @return pricePerVT The current mint price
     */
    function getValidatorTicketPrice() external view returns (uint256 pricePerVT);

    /**
     * @notice Returns true if the number of active Puffer Validators is over the burst threshold
     */
    function isOverBurstThreshold() external view returns (bool);

    /**
     * @notice Returns the locked ETH amount
     * @return lockedEthAmount The amount of ETH locked in Beacon chain
     */
    function getLockedEthAmount() external view returns (uint256 lockedEthAmount);
}
