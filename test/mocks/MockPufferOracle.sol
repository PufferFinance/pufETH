// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { IPufferOracle } from "../../src/interface/IPufferOracle.sol";

/**
 * @title MockPufferOracle
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
contract MockPufferOracle is IPufferOracle {
    /**
     * @dev Number of blocks
     */
    // slither-disable-next-line unused-state
    uint256 internal constant _UPDATE_INTERVAL = 1;

    /**
     * @dev Locked ETH amount in Beacon Chain
     * Slot 1
     */
    uint256 public lockedETH;
    /**
     * @dev Block number for when the values were updated
     * Slot 2
     */
    uint256 public lastUpdate;

    uint256 public numberOfActiveValidators;

    /**
     * @notice Simulate proofOfReservers from the guardians
     */
    function proofOfReserve(
        uint256 newLockedEthValue,
        uint256 blockNumber,
        uint256 newNumberOfActiveValidators,
        bytes[] calldata guardianSignatures
    ) external {
        if ((block.number - lastUpdate) < _UPDATE_INTERVAL) {
            revert OutsideUpdateWindow();
        }

        lockedETH = newLockedEthValue;
        lastUpdate = blockNumber;
        numberOfActiveValidators = newNumberOfActiveValidators;

        emit BackingUpdated(newLockedEthValue, blockNumber);
    }

    function provisionNode() external { }

    function getValidatorTicketPrice() external view returns (uint256 pricePerVT) { }

    function getLockedEthAmount() external view returns (uint256 lockedEthAmount) { }

    function isOverBurstThreshold() external view returns (bool) { }
}
