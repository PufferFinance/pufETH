// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

/**
 * @title PufferOracle
 * @author Puffer Finance
 * @dev Stores the reported values
 * @custom:security-contact security@puffer.fi
 */
contract PufferOracle {
    /**
     * @notice Emitted when the Guardians update state of the protocol
     * @param ethAmount is the ETH amount that is not locked in Beacon chain
     * @param lockedETH is the locked ETH amount in Beacon chain
     * @param pufETHTotalSupply is the total supply of the pufETH
     */
    event BackingUpdated(uint256 ethAmount, uint256 lockedETH, uint256 pufETHTotalSupply, uint256 blockNumber);

    /**
     * @dev Number of blocks
     */
    // slither-disable-next-line unused-state
    uint256 internal constant _UPDATE_INTERVAL = 1;

    /**
     * @dev Unlocked ETH amount
     * Slot 0
     */
    uint256 ethAmount;
    /**
     * @dev Locked ETH amount in Beacon Chain
     * Slot 1
     */
    uint256 lockedETH;
    /**
     * @dev pufETH total token supply
     * Slot 2
     */
    uint256 pufETHTotalSupply;
    /**
     * @dev Block number for when the values were updated
     * Slot 3
     */
    uint256 lastUpdate;

    /**
     * @notice Simulate proofOfReservers from the guardians
     */
    function proofOfReserve(
        uint256 newEthAmountValue,
        uint256 newLockedEthValue,
        uint256 pufETHTotalSupplyValue, // @todo what to do with this?
        uint256 blockNumber,
        uint256 numberOfActiveValidators,
        bytes[] calldata guardianSignatures
    ) external {
        // Check the signatures (reverts if invalid)
        // GUARDIAN_MODULE.validateProofOfReserve({
        //     ethAmount: ethAmount,
        //     lockedETH: lockedETH,
        //     pufETHTotalSupply: pufETHTotalSupply,
        //     blockNumber: blockNumber,
        //     numberOfActiveValidators: numberOfActiveValidators,
        //     guardianSignatures: guardianSignatures
        // });

        // if ((block.number - lastUpdate) < _UPDATE_INTERVAL) {
        //     revert OutsideUpdateWindow();
        // }

        ethAmount = newEthAmountValue;
        lockedETH = newLockedEthValue;
        pufETHTotalSupply = pufETHTotalSupply;
        lastUpdate = blockNumber;

        emit BackingUpdated(newEthAmountValue, newLockedEthValue, pufETHTotalSupplyValue, blockNumber);
    }
}
