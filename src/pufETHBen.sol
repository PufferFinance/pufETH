// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import { ERC20Permit } from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { IStETH } from "src/interface/IStETH.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IEigenLayer, IStrategy } from "src/interface/IEigenLayer.sol";
import { ISushiRouter } from "src/interface/ISushiRouter.sol";

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
contract pufETHBen is ERC20Permit, IPuffETH {
    using SafeERC20 for address;

    IStETH internal immutable _ST_ETH;

    IEigenLayer internal immutable _EIGEN_STRATEGY_MANAGER;

    IStrategy internal constant _EIGEN_STETH_STRATEGY = IStrategy(0x93c4b944D05dfe6df7645A86cd2206016c51564D);

    ISushiRouter internal constant _SUSHI_ROUTER = ISushiRouter(0x5550D13389bB70F45fCeF58f19f6b6e87F6e747d);

    /**
     * @param stETH address of the StETH token to wrap
     */
    constructor(IStETH stETH, IEigenLayer eigenStrategyManager)
        ERC20Permit("PufETH liquid restaking token")
        ERC20("PufETH liquid restaking token", "pufETH")
    {
        _ST_ETH = stETH;
        _EIGEN_STRATEGY_MANAGER = eigenStrategyManager;
        _ST_ETH.approve(address(_EIGEN_STRATEGY_MANAGER), type(uint256).max);
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
     * notice Deposits stETH into `stETH` EigenLayer strategy
     * @param amount the amount of stETH to deposit
     */
    function depositToEigenLayer(uint256 amount) public {
        _EIGEN_STRATEGY_MANAGER.depositIntoStrategy({ strategy: _EIGEN_STETH_STRATEGY, token: _ST_ETH, amount: amount });
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
        _mint(msg.sender, pufETHAmount);
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
}
