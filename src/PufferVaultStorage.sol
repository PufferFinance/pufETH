// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/**
 * @title PufferVaultStorage
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
abstract contract PufferVaultStorage {
    /**
     * @custom:storage-location erc7201:puffervault.storage
     * @dev +-----------------------------------------------------------+
     *      |                                                           |
     *      | DO NOT CHANGE, REORDER, REMOVE EXISTING STORAGE VARIABLES |
     *      |                                                           |
     *      +-----------------------------------------------------------+
     */
    struct VaultStorage {
        uint256 lidoLockedETH;
        uint256 eigenLayerPendingWithdrawalSharesAmount;
        bool isLidoWithdrawal;
        EnumerableSet.UintSet lidoWithdrawals;
        EnumerableSet.Bytes32Set eigenLayerWithdrawals;
    }

    // keccak256(abi.encode(uint256(keccak256("puffervault.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _VAULT_STORAGE_LOCATION =
        0x611ea165ca9257827fc43d2954fdae7d825e82c825d9037db9337fa1bfa93100;

    function _getPufferVaultStorage() internal pure returns (VaultStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := _VAULT_STORAGE_LOCATION
        }
    }
}
