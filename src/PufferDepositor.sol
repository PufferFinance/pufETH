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
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ISushiRouter } from "src/interface/Other/ISushiRouter.sol";
import { IPufferDepositor } from "src/interface/IPufferDepositor.sol";

/**
 * @title PufferDepositor
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
contract PufferDepositor is IPufferDepositor, AccessManagedUpgradeable, UUPSUpgradeable {
    using SafeERC20 for address;

    IERC20 internal constant _USDT = IERC20(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 internal constant _USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    IStETH internal immutable _ST_ETH;
    IWstETH internal constant _WST_ETH = IWstETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);

    ISushiRouter internal constant _SUSHI_ROUTER = ISushiRouter(0x5550D13389bB70F45fCeF58f19f6b6e87F6e747d);

    /**
     * @dev The Puffer Vault contract address
     */
    PufferVault public immutable _PUFFER_VAULT;

    /**
     * @custom:storage-location erc7201:PufferDepositor.storage
     * @dev +-----------------------------------------------------------+
     *      |                                                           |
     *      | DO NOT CHANGE, REORDER, REMOVE EXISTING STORAGE VARIABLES |
     *      |                                                           |
     *      +-----------------------------------------------------------+
     */
    // keccak256(abi.encode(uint256(keccak256("PufferDepositor.storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant _DEPOSITOR_STORAGE_LOCATION =
        0x5049f1e65454f7e13e70ec95efa125d25c296b5dfc70ade7425c2ab823e3e200;

    struct DepositorStorage {
        /**
         * @dev Allowed Tokens
         * Slot 0
         */
        mapping(IERC20 token => bool allowed) allowedTokens;
    }

    constructor(PufferVault pufferVault, IStETH stETH) {
        _PUFFER_VAULT = pufferVault;
        _ST_ETH = stETH;
        _disableInitializers();
    }

    function initialize(address accessManager) external initializer {
        __AccessManaged_init(accessManager);
        SafeERC20.safeIncreaseAllowance(_ST_ETH, address(_PUFFER_VAULT), type(uint256).max);
        _allowToken(_USDT);
        _allowToken(_USDC);
    }

    /**
     * @notice Swaps `amountIn` of `tokenIn` for stETH and deposits it into the Puffer Vault
     * @param tokenIn The address of the token being swapped
     * @param amountIn The amount of `tokenIn` to swap
     * @param amountOutMin The minimum amount of stETH to receive from the swap
     * @param routeCode The encoded route for the swap
     * @return pufETHAmount The amount of pufETH received from the deposit
     */
    function swapAndDeposit(address tokenIn, uint256 amountIn, uint256 amountOutMin, bytes calldata routeCode)
        public
        virtual
        returns (uint256 pufETHAmount)
    {
        DepositorStorage storage $ = _getDepositorStorage();

        // It is more readable than !
        // slither-disable-next-line boolean-equal
        if ($.allowedTokens[IERC20(tokenIn)] == false) {
            revert TokenNotAllowed(tokenIn);
        }

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

        return _PUFFER_VAULT.deposit(stETHAmountOut, msg.sender);
    }

    /**
     * @notice Swaps `permitData.amount` of `tokenIn` for stETH using a permit and deposits it into the Puffer Vault
     * @param tokenIn The address of the token being swapped
     * @param amountOutMin The minimum amount of stETH to receive from the swap
     * @param permitData The permit data containing the approval information
     * @param routeCode The encoded route for the swap
     * @return pufETHAmount The amount of pufETH received from the deposit
     */
    function swapAndDepositWithPermit(
        address tokenIn,
        uint256 amountOutMin,
        IPufferDepositor.Permit calldata permitData,
        bytes calldata routeCode
    ) public virtual returns (uint256 pufETHAmount) {
        DepositorStorage storage $ = _getDepositorStorage();

        // It is more readable than !
        // slither-disable-next-line boolean-equal
        if ($.allowedTokens[IERC20(tokenIn)] == false) {
            revert TokenNotAllowed(tokenIn);
        }

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

        return _PUFFER_VAULT.deposit(stETHAmountOut, msg.sender);
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

        return _PUFFER_VAULT.deposit(stETHAmount, msg.sender);
    }

    /**
     * @notice Allows the specified token for deposit
     * Restricted access
     * @param token The token to be allowed for deposit
     */
    function allowToken(IERC20 token) external restricted {
        _allowToken(token);
    }

    /**
     * @notice Disallows the specified token for deposit
     * Restricted access
     * @param token The token to be disallowed for deposit
     */
    function disallowToken(IERC20 token) external restricted {
        _disallowToken(token);
    }

    /**
     * @dev Authorizes an upgrade to a new implementation
     * Restricted access
     * @param newImplementation The address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation) internal virtual override restricted { }

    function _allowToken(IERC20 token) internal virtual {
        DepositorStorage storage $ = _getDepositorStorage();
        $.allowedTokens[token] = true;
        emit TokenAllowed(token);
    }

    function _disallowToken(IERC20 token) internal virtual {
        DepositorStorage storage $ = _getDepositorStorage();
        $.allowedTokens[token] = false;
        emit TokenDisallowed(token);
    }

    function _getDepositorStorage() private pure returns (DepositorStorage storage $) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := _DEPOSITOR_STORAGE_LOCATION
        }
    }
}
