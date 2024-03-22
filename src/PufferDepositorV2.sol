// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { ERC20Permit } from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { AccessManagedUpgradeable } from
    "@openzeppelin-contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IStETH } from "./interface/Lido/IStETH.sol";
import { IWstETH } from "./interface/Lido/IWstETH.sol";
import { PufferVaultV2 } from "./PufferVaultV2.sol";
import { PufferDepositorStorage } from "./PufferDepositorStorage.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IPufferDepositorV2 } from "./interface/IPufferDepositorV2.sol";
import { Permit } from "./structs/Permit.sol";

/**
 * @title PufferDepositorV2
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
contract PufferDepositorV2 is IPufferDepositorV2, PufferDepositorStorage, AccessManagedUpgradeable, UUPSUpgradeable {
    using SafeERC20 for address;

    IStETH internal immutable _ST_ETH;
    IWstETH internal constant _WST_ETH = IWstETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

    /**
     * @dev Wallet that transferred pufETH to the PufferDepositor by mistake.
     */
    address private constant PUFFER = 0x8A0C1e5cEA8e0F6dF341C005335E7fe5ed18A0a0;

    /**
     * @dev The Puffer Vault contract address
     */
    PufferVaultV2 public immutable PUFFER_VAULT;

    constructor(PufferVaultV2 pufferVault, IStETH stETH) payable {
        PUFFER_VAULT = pufferVault;
        _ST_ETH = stETH;
        _disableInitializers();
    }

    /**
     * @notice Returns the pufETH sent to this contract by mistake
     */
    function initialize() public reinitializer(2) {
        // https://etherscan.io/token/0xd9a442856c234a39a81a089c06451ebaa4306a72?a=0x4aa799c5dfc01ee7d790e3bf1a7c2257ce1dceff
        // slither-disable-next-line unchecked-transfer
        PUFFER_VAULT.transfer(PUFFER, 0.201 ether);
    }

    /**
     * @inheritdoc IPufferDepositorV2
     */
    function depositWstETH(Permit calldata permitData, address recipient)
        external
        restricted
        returns (uint256 pufETHAmount)
    {
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

        _WST_ETH.unwrap(permitData.amount);

        // The PufferDepositor is not supposed to hold any stETH, so we sharesOf(PufferDepositor) to the PufferVault immediately
        return PUFFER_VAULT.depositStETH(_ST_ETH.sharesOf(address(this)), recipient);
    }

    /**
     * @inheritdoc IPufferDepositorV2
     */
    function depositStETH(Permit calldata permitData, address recipient)
        external
        restricted
        returns (uint256 pufETHAmount)
    {
        try ERC20Permit(address(_ST_ETH)).permit({
            owner: msg.sender,
            spender: address(this),
            value: permitData.amount,
            deadline: permitData.deadline,
            v: permitData.v,
            s: permitData.s,
            r: permitData.r
        }) { } catch { }

        // Transfer stETH from user to this contract. The amount received here can be 1-2 wei lower than the actual permitData.amount
        SafeERC20.safeTransferFrom(IERC20(address(_ST_ETH)), msg.sender, address(this), permitData.amount);

        // The PufferDepositor is not supposed to hold any stETH, so we sharesOf(PufferDepositor) to the PufferVault immediately
        return PUFFER_VAULT.depositStETH(_ST_ETH.sharesOf(address(this)), recipient);
    }

    /**
     * @dev Authorizes an upgrade to a new implementation
     * Restricted access
     * @param newImplementation The address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal virtual override restricted { }
}
