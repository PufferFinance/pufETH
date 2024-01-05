// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import { ERC20Permit } from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { ERC20Upgradeable } from "@openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC20PermitUpgradeable } from
    "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IStETH } from "src/interface/IStETH.sol";
import { LidoVault } from "src/LidoVault.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IEigenLayer, IStrategy } from "src/interface/IEigenLayer.sol";
import { ISushiRouter } from "src/interface/ISushiRouter.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";
import { console } from "forge-std/console.sol";

interface IPuffETH is IERC20 {
    error InvalidAmount();

    /**
     * @dev Struct representing a permit for a specific action.
     */
    struct Permit {
        address owner;
        uint256 deadline;
        uint256 amount;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
}

interface IWstETH {
    function wrap(uint256 _stETHAmount) external returns (uint256);
}

/**
 * @title StETH token wrapper with static balances.
 * @dev It's an ERC20 token that represents the account's share of the total
 * supply of stETH tokens. pufETH token's balance only changes on transfers,
 * unlike StETH that is also changed when oracles report staking rewards and
 * penalties. It's a "power user" token for DeFi protocols which don't
 * support rebasable tokens.
 *
 * The contract is also a trustless wrapper that accepts stETH tokens and mints
 * pufETH in return. Then the user unwraps, the contract burns user's pufETH
 * and sends user locked stETH in return.
 *
 * The contract provides the staking shortcut: user can send ETH with regular
 * transfer and get pufETH in return. The contract will send ETH to Lido submit
 * method, staking it and wrapping the received stETH.
 *
 */
contract pufETH is UUPSUpgradeable, ERC20Upgradeable, ERC20PermitUpgradeable, IPuffETH {
    using SafeERC20 for address;

    IStETH internal immutable _ST_ETH;
    IWstETH internal immutable _WST_ETH = IWstETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    IEigenLayer internal immutable _EIGEN_STRATEGY_MANAGER;
    LidoVault public immutable _LIDO_VAULT;

    IStrategy internal constant _EIGEN_STETH_STRATEGY = IStrategy(0x93c4b944D05dfe6df7645A86cd2206016c51564D);

    ISushiRouter internal constant _SUSHI_ROUTER = ISushiRouter(0x5550D13389bB70F45fCeF58f19f6b6e87F6e747d);

    /**
     * @param stETH address of the StETH token to wrap
     */
    constructor(IStETH stETH, IEigenLayer eigenStrategyManager, LidoVault lidoVault) {
        _ST_ETH = stETH;
        _EIGEN_STRATEGY_MANAGER = eigenStrategyManager;
        _LIDO_VAULT = lidoVault;
        _disableInitializers();
    }

    function initialize() external initializer {
        __ERC20_init("PufETH liquid restaking token", "pufETH");
        __ERC20Permit_init("PufETH liquid restaking token");
        SafeERC20.safeIncreaseAllowance(_ST_ETH, address(_EIGEN_STRATEGY_MANAGER), type(uint256).max);
        SafeERC20.safeIncreaseAllowance(_ST_ETH, address(_LIDO_VAULT), type(uint256).max);
    }

    // function calculateEthToPufETHAmount(uint256 ethAmountDeposited) public view returns (uint256) {
    //     uint256 ownedETH = _getOwnedLidoETHAmount();
    //     return _calculateETHToPufETHAmount(ethAmountDeposited);
    // }

    function _calculateETHToPufETHAmount(uint256 ethAmount) public view returns (uint256) {
        // @todo
        // Get Data from PufferProtocol, for 'normal' eth deposits

        uint256 exchangeRate;

        // slither-disable-next-line incorrect-equality
        if (totalSupply() == 0) {
            exchangeRate = FixedPointMathLib.WAD;
        } else {
            exchangeRate = FixedPointMathLib.divWad(_LIDO_VAULT.getBackingEthAmount(), totalSupply());
        }

        //@todo don't forget to account for eigenlayer deposits in stETH strategy contract

        return FixedPointMathLib.divWad(ethAmount, exchangeRate);
    }

    function _getOwnedLidoETHAmount() internal view returns (uint256 ownedETH) {
        uint256 shares = _ST_ETH.sharesOf(address(this));
        ownedETH = _ST_ETH.getPooledEthByShares(shares);
    }

    function depositStETH(uint256 stETHAmount) external returns (uint256 mintedPufETH) {
        _ST_ETH.transferFrom(msg.sender, address(this), stETHAmount);
        uint256 shares = _ST_ETH.sharesOf(address(this));
        mintedPufETH = _calculateETHToPufETHAmount(_ST_ETH.getPooledEthByShares(shares));
        _ST_ETH.transferShares(address(_LIDO_VAULT), shares);
        _mint(msg.sender, mintedPufETH);
    }

    /**
     * @notice Exchanges stETH to pufETH
     * @param stETHAmount amount of stETH to wrap in exchange for pufETH
     * @dev Requirements:
     *  - `_stETHAmount` must be non-zero
     *  - msg.sender must approve at least `stETHAmount` stETH to this
     *    contract.
     *  - msg.sender must have at least `stETHAmount` of stETH.
     * User should first approve _stETHAmount to the pufETH contract
     * @return pufETHAmount Amount of pufETH user receives after wrap
     */
    function wrap(uint256 stETHAmount) external returns (uint256) {
        if (stETHAmount == 0) {
            revert InvalidAmount();
        }
        _ST_ETH.transferFrom(msg.sender, address(this), stETHAmount);
        return _wrap(stETHAmount);
    }

    /**
     * @notice Exchanges pufETH to stETH
     * @param pufETHAmount amount of pufETH to uwrap in exchange for stETH
     * @dev Requirements:
     *  - `pufETHAmount` must be non-zero
     *  - msg.sender must have at least `pufETHAmount` pufETH.
     * @return stETHAmount Amount of stETH user receives after unwrap
     */
    function unwrap(uint256 pufETHAmount) external returns (uint256 stETHAmount) {
        if (pufETHAmount == 0) {
            revert InvalidAmount();
        }
        stETHAmount = _ST_ETH.getPooledEthByShares(pufETHAmount);
        _burn(msg.sender, pufETHAmount);
        _ST_ETH.transfer(msg.sender, stETHAmount);
    }

    function swapAndDeposit(address tokenIn, uint256 amountIn, uint256 amountOutMin, bytes calldata routeCode)
        public
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

        return _wrap(stETHAmountOut);
    }

    function swapAndDepositWithPermit(
        address tokenIn,
        uint256 amountOutMin,
        Permit calldata permitData,
        bytes calldata routeCode
    ) public returns (uint256 pufETHAmount) {
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

        return _wrap(stETHAmountOut);
    }

    /**
     * @notice Shortcut to stake ETH and auto-wrap returned stETH
     */
    receive() external payable {
        uint256 shares = _ST_ETH.submit{ value: msg.value }(address(0));
        _mint(msg.sender, shares);
    }

    function _wrap(uint256 stETHAmount) internal returns (uint256 pufETHAmount) {
        pufETHAmount = _ST_ETH.getSharesByPooledEth(stETHAmount);
        _ST_ETH.transferShares(address(_LIDO_VAULT), pufETHAmount);
        _mint(msg.sender, pufETHAmount);
    }

    function _getPufETHtoETHExchangeRate() internal view returns (uint256) {
        uint256 pufETHTotalSupply = 0;

        // slither-disable-next-line incorrect-equality
        if (pufETHTotalSupply == 0) {
            return FixedPointMathLib.WAD;
        }

        return FixedPointMathLib.divWad((0 + 0), pufETHTotalSupply);
    }

    /**
     * @notice Get amount of pufETH for a given amount of stETH
     * @param _stETHAmount amount of stETH
     * @return Amount of pufETH for a given stETH amount
     */
    function getpufETHByStETH(uint256 _stETHAmount) external view returns (uint256) {
        return _ST_ETH.getSharesByPooledEth(_stETHAmount);
    }

    /**
     * @notice Get amount of stETH for a given amount of pufETH
     * @param _pufETHAmount amount of pufETH
     * @return Amount of stETH for a given pufETH amount
     */
    function getStETHBypufETH(uint256 _pufETHAmount) external view returns (uint256) {
        return _ST_ETH.getPooledEthByShares(_pufETHAmount);
    }

    /**
     * @notice Get amount of stETH for a one pufETH
     * @return Amount of stETH for 1 pufETH
     */
    function stEthPerToken() external view returns (uint256) {
        return _ST_ETH.getPooledEthByShares(1 ether);
    }

    /**
     * @notice Get amount of pufETH for a one stETH
     * @return Amount of pufETH for a 1 stETH
     */
    function tokensPerStEth() external view returns (uint256) {
        return _ST_ETH.getSharesByPooledEth(1 ether);
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override {
        //@todo anybody can do it
    }
}
