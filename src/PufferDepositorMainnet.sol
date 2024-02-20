// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { ERC20Permit } from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { AccessManagedUpgradeable } from
    "@openzeppelin-contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IStETH } from "./interface/Lido/IStETH.sol";
import { IWstETH } from "./interface/Lido/IWstETH.sol";
import { PufferVaultMainnet } from "./PufferVaultMainnet.sol";
import { PufferDepositorStorage } from "./PufferDepositorStorage.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IPufferDepositorMainnet } from "./interface/IPufferDepositorMainnet.sol";
import { Permit } from "./structs/Permit.sol";

/**
 * @title PufferDepositor
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
contract PufferDepositorMainnet is
    IPufferDepositorMainnet,
    PufferDepositorStorage,
    AccessManagedUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for address;

    IStETH internal immutable _ST_ETH;
    IWstETH internal constant _WST_ETH = IWstETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

    /**
     * @dev The Puffer Vault contract address
     */
    PufferVaultMainnet public immutable PUFFER_VAULT;

    constructor(PufferVaultMainnet pufferVault, IStETH stETH) payable {
        PUFFER_VAULT = pufferVault;
        _ST_ETH = stETH;
        _disableInitializers();
    }

    /**
     * @inheritdoc IPufferDepositorMainnet
     */
    function depositWstETH(Permit calldata permitData) external restricted returns (uint256 pufETHAmount) {
        try ERC20Permit(address(_WST_ETH)).permit({
            owner: msg.sender,
            spender: address(this),
            value: permitData.amount,
            deadline: permitData.deadline,
            v: permitData.v,
            s: permitData.s,
            r: permitData.r
        }) { } catch { }

        SafeERC20.safeTransferFrom(IERC20(address(_WST_ETH)), msg.sender, address(this), permitData.amount);
        uint256 stETHAmount = _WST_ETH.unwrap(permitData.amount);

        return PUFFER_VAULT.depositStETH(stETHAmount, msg.sender);
    }

    /**
     * @inheritdoc IPufferDepositorMainnet
     */
    function depositStETH(Permit calldata permitData) external restricted returns (uint256 pufETHAmount) {
        try ERC20Permit(address(_ST_ETH)).permit({
            owner: msg.sender,
            spender: address(this),
            value: permitData.amount,
            deadline: permitData.deadline,
            v: permitData.v,
            s: permitData.s,
            r: permitData.r
        }) { } catch { }

        SafeERC20.safeTransferFrom(IERC20(address(_ST_ETH)), msg.sender, address(this), permitData.amount);

        return PUFFER_VAULT.depositStETH(permitData.amount, msg.sender);
    }

    /**
     * @dev Authorizes an upgrade to a new implementation
     * Restricted access
     * @param newImplementation The address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal virtual override restricted { }
}
