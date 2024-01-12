// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

/**
 * @title PufferDepositorStorage
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
abstract contract PufferDepositorStorage {
    /**
     * @custom:storage-location erc7201:pufferdepositor.storage
     * @dev +-----------------------------------------------------------+
     *      |                                                           |
     *      | DO NOT CHANGE, REORDER, REMOVE EXISTING STORAGE VARIABLES |
     *      |                                                           |
     *      +-----------------------------------------------------------+
     */
    struct DepositorStorage {
        /**
         * @dev Allowed Tokens
         * Slot 0
         */
        mapping(IERC20 token => bool allowed) allowedTokens;
    }

    // keccak256(abi.encode(uint256(keccak256("pufferdepositor.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _DEPOSITOR_STORAGE_LOCATION =
        0xfe00eacac09c3a4f9370afc23b4b368378559810af33ed029b1efbfeeaccaf00;

    function _getDepositorStorage() internal pure returns (DepositorStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := _DEPOSITOR_STORAGE_LOCATION
        }
    }
}
