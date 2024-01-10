// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

abstract contract PufferVaultStorage {
    /// @custom:storage-location erc7201:puffervault.storage.ERC4626
    struct VaultStorage {
        uint256 lidoLockedETH;
        bool isLidoWithdrawal;
    }

    // keccak256(abi.encode(uint256(keccak256("puffervault.storage.ERC4626")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant ERC4626StorageLocation = 0x6d4971415142040fa945ebf44b5dec920e7693eb61c9c44e4167ab643762ec00;

    function _getPufferVaultStorage() internal pure returns (VaultStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := ERC4626StorageLocation
        }
    }
}
