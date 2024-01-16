// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { ERC20Permit } from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { AccessManagedUpgradeable } from
    "@openzeppelin-contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IStETH } from "src/interface/Lido/IStETH.sol";
import { IWstETH } from "src/interface/Lido/IWstETH.sol";
import { PufferVault } from "src/PufferVault.sol";
import { PufferDepositorStorage } from "src/PufferDepositorStorage.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ISushiRouter } from "src/interface/Other/ISushiRouter.sol";
import { IPufferDepositor } from "src/interface/IPufferDepositor.sol";

/**
 * @title PufferDepositor
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
contract PufferDepositor is IPufferDepositor, PufferDepositorStorage, AccessManagedUpgradeable, UUPSUpgradeable {
    using SafeERC20 for address;

    IStETH internal immutable _ST_ETH;
    IWstETH internal constant _WST_ETH = IWstETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

    ISushiRouter internal constant _SUSHI_ROUTER = ISushiRouter(0x5550D13389bB70F45fCeF58f19f6b6e87F6e747d);

    /**
     * @dev The Puffer Vault contract address
     */
    PufferVault public immutable PUFFER_VAULT;

    constructor(PufferVault pufferVault, IStETH stETH) payable {
        PUFFER_VAULT = pufferVault;
        _ST_ETH = stETH;
        _disableInitializers();
    }

    function initialize(address accessManager) external initializer {
        __AccessManaged_init(accessManager);
        SafeERC20.safeIncreaseAllowance(_ST_ETH, address(PUFFER_VAULT), type(uint256).max);
    }

    /**
     * @inheritdoc IPufferDepositor
     */
    function swapAndDeposit(address tokenIn, uint256 amountIn, uint256 amountOutMin, bytes calldata routeCode)
        public
        virtual
        returns (uint256 pufETHAmount)
    {
        SafeERC20.safeTransferFrom(IERC20(tokenIn), msg.sender, address(this), amountIn);
        SafeERC20.safeIncreaseAllowance(IERC20(tokenIn), address(_SUSHI_ROUTER), amountIn);

        uint256 stETHAmountOut = _SUSHI_ROUTER.processRoute({
            tokenIn: tokenIn,
            amountIn: amountIn,
            tokenOut: address(_ST_ETH),
            amountOutMin: amountOutMin,
            to: address(this),
            route: routeCode
        });

        return PUFFER_VAULT.deposit(stETHAmountOut, msg.sender);
    }

    /**
     * @inheritdoc IPufferDepositor
     */
    function swapAndDepositWithPermit(
        address tokenIn,
        uint256 amountOutMin,
        IPufferDepositor.Permit calldata permitData,
        bytes calldata routeCode
    ) public virtual returns (uint256 pufETHAmount) {
        try ERC20Permit(address(tokenIn)).permit({
            owner: permitData.owner,
            spender: address(this),
            value: permitData.amount,
            deadline: permitData.deadline,
            v: permitData.v,
            s: permitData.s,
            r: permitData.r
        }) { } catch { }

        SafeERC20.safeTransferFrom(IERC20(tokenIn), msg.sender, address(this), permitData.amount);
        SafeERC20.safeIncreaseAllowance(IERC20(tokenIn), address(_SUSHI_ROUTER), permitData.amount);

        uint256 stETHAmountOut = _SUSHI_ROUTER.processRoute({
            tokenIn: tokenIn,
            amountIn: permitData.amount,
            tokenOut: address(_ST_ETH),
            amountOutMin: amountOutMin,
            to: address(this),
            route: routeCode
        });

        return PUFFER_VAULT.deposit(stETHAmountOut, msg.sender);
    }

    /**
     * @notice Deposits wrapped stETH (wstETH) into the Puffer Vault
     * @param permitData The permit data containing the approval information
     * @return pufETHAmount The amount of pufETH received from the deposit
     */
    function depositWstETH(IPufferDepositor.Permit calldata permitData) external returns (uint256 pufETHAmount) {
        try ERC20Permit(address(_WST_ETH)).permit({
            owner: permitData.owner,
            spender: address(this),
            value: permitData.amount,
            deadline: permitData.deadline,
            v: permitData.v,
            s: permitData.s,
            r: permitData.r
        }) { } catch { }

        SafeERC20.safeTransferFrom(IERC20(address(_WST_ETH)), msg.sender, address(this), permitData.amount);
        uint256 stETHAmount = _WST_ETH.unwrap(permitData.amount);

        return PUFFER_VAULT.deposit(stETHAmount, msg.sender);
    }

    /**
     * @dev Authorizes an upgrade to a new implementation
     * Restricted access
     * @param newImplementation The address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal virtual override restricted { }
}
