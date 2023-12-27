// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { ERC20Permit } from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { IStETH } from "src/interface/IStETH.sol";

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
contract pufETHBen is ERC20Permit {
    IStETH public immutable _stETH;

    /**
     * @param stETH address of the StETH token to wrap
     */
    constructor(IStETH stETH)
        ERC20Permit("PufETH liquid restaking token")
        ERC20("PufETH liquid restaking token", "pufETH")
    {
        _stETH = stETH;
    }

    /**
     * @notice Exchanges stETH to pufETH
     * @param _stETHAmount amount of stETH to wrap in exchange for pufETH
     * @dev Requirements:
     *  - `_stETHAmount` must be non-zero
     *  - msg.sender must approve at least `_stETHAmount` stETH to this
     *    contract.
     *  - msg.sender must have at least `_stETHAmount` of stETH.
     * User should first approve _stETHAmount to the pufETH contract
     * @return Amount of pufETH user receives after wrap
     */
    function wrap(uint256 _stETHAmount) external returns (uint256) {
        require(_stETHAmount > 0, "pufETH: can't wrap zero stETH");
        uint256 pufETHAmount = _stETH.getSharesByPooledEth(_stETHAmount);
        _mint(msg.sender, pufETHAmount);
        _stETH.transferFrom(msg.sender, address(this), _stETHAmount);
        return pufETHAmount;
    }

    /**
     * @notice Exchanges pufETH to stETH
     * @param _pufETHAmount amount of pufETH to uwrap in exchange for stETH
     * @dev Requirements:
     *  - `_pufETHAmount` must be non-zero
     *  - msg.sender must have at least `_pufETHAmount` pufETH.
     * @return Amount of stETH user receives after unwrap
     */
    function unwrap(uint256 _pufETHAmount) external returns (uint256) {
        require(_pufETHAmount > 0, "pufETH: zero amount unwrap not allowed");
        uint256 stETHAmount = _stETH.getPooledEthByShares(_pufETHAmount);
        _burn(msg.sender, _pufETHAmount);
        _stETH.transfer(msg.sender, stETHAmount);
        return stETHAmount;
    }

    /**
     * @notice Shortcut to stake ETH and auto-wrap returned stETH
     */
    receive() external payable {
        uint256 shares = _stETH.submit{ value: msg.value }(address(0));
        _mint(msg.sender, shares);
    }

    /**
     * @notice Get amount of pufETH for a given amount of stETH
     * @param _stETHAmount amount of stETH
     * @return Amount of pufETH for a given stETH amount
     */
    function getpufETHByStETH(uint256 _stETHAmount) external view returns (uint256) {
        return _stETH.getSharesByPooledEth(_stETHAmount);
    }

    /**
     * @notice Get amount of stETH for a given amount of pufETH
     * @param _pufETHAmount amount of pufETH
     * @return Amount of stETH for a given pufETH amount
     */
    function getStETHBypufETH(uint256 _pufETHAmount) external view returns (uint256) {
        return _stETH.getPooledEthByShares(_pufETHAmount);
    }

    /**
     * @notice Get amount of stETH for a one pufETH
     * @return Amount of stETH for 1 pufETH
     */
    function stEthPerToken() external view returns (uint256) {
        return _stETH.getPooledEthByShares(1 ether);
    }

    /**
     * @notice Get amount of pufETH for a one stETH
     * @return Amount of pufETH for a 1 stETH
     */
    function tokensPerStEth() external view returns (uint256) {
        return _stETH.getSharesByPooledEth(1 ether);
    }
}
