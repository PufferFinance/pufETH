// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { IPufferOracleV2 } from "../../src/interface/IPufferOracleV2.sol";

/**
 * @title MockPufferOracle
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
contract MockPufferOracle is IPufferOracleV2 {
    /**
     * @dev Number of blocks
     */
    // slither-disable-next-line unused-state
    uint256 internal constant _UPDATE_INTERVAL = 1;

    uint152 public lockedETH;

    uint56 public lastUpdate;

    uint256 public numberOfActiveValidators;

    function getLastUpdate() external view returns (uint256) {
        return lastUpdate;
    }

    function getTotalNumberOfValidators() external pure returns (uint256) {
        return 99999;
    }

    function provisionNode() external { }
    function exitValidators(uint256) external { }

    function getValidatorTicketPrice() external view returns (uint256 pricePerVT) { }

    function getLockedEthAmount() external view returns (uint256 lockedEthAmount) { }

    function isOverBurstThreshold() external view returns (bool) { }
}
