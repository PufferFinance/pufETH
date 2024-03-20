// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

interface IStETH is IERC20 {
    /**
     * @return the amount of Ether that corresponds to `_sharesAmount` token shares.
     */
    function getPooledEthByShares(uint256 _sharesAmount) external view returns (uint256);

    /**
     * @return the amount of shares that corresponds to `_ethAmount` protocol-controlled Ether.
     */
    function getSharesByPooledEth(uint256 _pooledEthAmount) external view returns (uint256);

    function getTotalPooledEther() external view returns (uint256);

    function transferShares(address _recipient, uint256 _sharesAmount) external returns (uint256);

    function transferSharesFrom(address _sender, address _recipient, uint256 _sharesAmount)
        external
        returns (uint256);

    /**
     * @return the amount of tokens in existence.
     *
     * @dev Always equals to `_getTotalPooledEther()` since token amount
     * is pegged to the total amount of Ether controlled by the protocol.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Process user deposit, mints liquid tokens and increase the pool buffer
     * @param _referral address of referral.
     * @return amount of StETH shares generated
     */
    function submit(address _referral) external payable returns (uint256);

    /**
     * @notice Returns the number of shares owned by `_account`
     */
    function sharesOf(address _account) external view returns (uint256);
}
