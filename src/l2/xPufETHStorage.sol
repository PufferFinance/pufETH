// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { IXERC20 } from "../interface/IXERC20.sol";

/**
 * @title xPufETHStorage
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
abstract contract xPufETHStorage {
    /**
     * @custom:storage-location erc7201:xPufETH.storage
     * @dev +-----------------------------------------------------------+
     *      |                                                           |
     *      | DO NOT CHANGE, REORDER, REMOVE EXISTING STORAGE VARIABLES |
     *      |                                                           |
     *      +-----------------------------------------------------------+
     */
    struct xPufETH {
        /**
         * @notice The address of the lockbox contract
         */
        address lockbox;
        /**
         * @notice Maps bridge address to bridge configurations
         */
        mapping(address bridge => IXERC20.Bridge config) bridges;
    }

    // keccak256(abi.encode(uint256(keccak256("xPufETH.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _STORAGE_LOCATION = 0xfee41a6d2b86b757dd00cd2166d8727686a349977cbc2b6b6a2ca1c3e7215000;

    function _getXPufETHStorage() internal pure returns (xPufETH storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := _STORAGE_LOCATION
        }
    }
}
