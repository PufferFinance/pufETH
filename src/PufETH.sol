// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {ERC20Permit} from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import {IERC20Permit} from "openzeppelin/token/ERC20/extensions/IERC20Permit.sol";

interface IWithdrawalPool {
    /**
     * @notice Burns `pufETHAmount` and sends the ETH to `to`
     * @dev You need to approve `pufETHAmount` to this contract by calling pool.approve
     * @return ETH Amount redeemed
     */
    function withdrawETH(
        address to,
        uint256 pufETHAmount
    ) external returns (uint256);
}

interface IPufferPool is IERC20 {
    /**
     * @notice Deposits ETH and `msg.sender` receives pufETH in return
     * @return pufETH amount minted
     * @dev Signature "0xf6326fb3"
     */
    function depositETH() external payable returns (uint256);

    /**
     * @notice Calculates the equivalent pufETH amount for a given `amount` of ETH based on the current ETH:pufETH exchange rate
     * Suppose that the exchange rate is 1 : 1.05 and the user is wondering how much `pufETH` will he receive if he deposits `amount` ETH.
     *
     * outputAmount = amount * (1 / exchangeRate) // because the exchange rate is 1 to 1.05
     * outputAmount = amount * (1 / 1.05)
     * outputAmount = amount * 0.95238095238
     *
     * if the user is depositing 1 ETH, he would get 0.95238095238 pufETH in return
     *
     * @param amount The amount of ETH to be converted to pufETH
     * @dev Signature "0x1b5ebe05"
     * @return The equivalent amount of pufETH
     */
    function calculateETHToPufETHAmount(
        uint256 amount
    ) external view returns (uint256);

    /**
     * @notice Calculates the equivalent ETH amount for a given `pufETHAmount` based on the current ETH:pufETH exchange rate
     *
     * Suppose that the exchange rate is 1 : 1.05 and the user is wondering how much `pufETH` will he receive if he wants to redeem `pufETHAmount` worth of pufETH.
     *
     * outputAmount = pufETHAmount * (1.05 / 1) // because the exchange rate is 1 to 1.05 (ETH to pufETH)
     * outputAmount = pufETHAmount * 1.05
     *
     * if the user is redeeming 1 pufETH, he would get 1.05 ETH in return
     *
     * NOTE: The calculation does not take in the account any withdrawal fee.
     *
     * @param pufETHAmount The amount of pufETH to be converted to ETH
     * @dev Signature "0x149a74ed"
     * @return The equivalent amount of ETH
     */
    function calculatePufETHtoETHAmount(
        uint256 pufETHAmount
    ) external view returns (uint256);
}

interface IUSDC is IERC20, IERC20Permit {
    function transferWithAuthorization(
        address,
        address,
        uint256,
        uint256,
        uint256,
        bytes32,
        uint8,
        bytes32,
        bytes32
    ) external;
}

interface IUSDT {
    function transfer(address to, uint256 amount) external;

    function transferFrom(address from, address to, uint256 amount) external;

    function approve(address spender, uint256 amount) external;

    function basisPointsRate() external view returns (uint256);

    function balanceOf(address) external view returns (uint256);
}

interface IStETH is IERC20 {
    /**
     * @return the amount of Ether that corresponds to `_sharesAmount` token shares.
     */
    function getPooledEthByShares(
        uint256 _sharesAmount
    ) external view returns (uint256);

    /**
     * @return the amount of shares that corresponds to `_ethAmount` protocol-controlled Ether.
     */
    function getSharesByPooledEth(
        uint256 _pooledEthAmount
    ) external view returns (uint256);

    /**
     * @dev Process user deposit, mints liquid tokens and increase the pool buffer
     * @param _referral address of referral.
     * @return amount of StETH shares generated
     */
    function submit(address _referral) external payable returns (uint256);
}

interface IPufETH is IERC20 {
    // Deposit stETH without swapping
    function depositStETH(uint256 _stETHAmount) external returns (uint256);

    // Performs Swap from ETH to stETH
    function depositETH(uint256 _ETHAmount) external returns (uint256);

    // Performs Swap from USDC to stETH
    function depositUSDC(uint256 _USDCAmount) external returns (uint256);

    // Performs Swap from USDC to stETH
    function depositUSDT(uint256 _USDTAmount) external returns (uint256);

    // Deposit stETH for EigenPoints
    function depositToEigenLayer(
        uint256 _stETHAmount
    ) external returns (uint256);

    // Retrieve stETH from EigenLayer
    function withdrawFromEigenLayer(
        uint256 _stETHAmount
    ) external returns (uint256);

    // Trigger redemptions from Lido
    function withdrawStETHToETH(
        uint256 _stETHAmount
    ) external returns (uint256);
}

interface IStETHVault {
    // Deposit stETH for EigenPoints
    function depositToEigenLayer(uint256 amount) external returns (uint256);
}

interface IPufETHVault {}

interface IEigenLayer {
    function depositStETH(uint256 _stETHAmount) external returns (uint256);
}

/**
 * @title StETH token wrapper with static balances.
 * @dev It's an ERC20 token that represents the account's share of the total
 * supply of stETH tokens. WstETH token's balance only changes on transfers,
 * unlike StETH that is also changed when oracles report staking rewards and
 * penalties. It's a "power user" token for DeFi protocols which don't
 * support rebasable tokens.
 *
 * The contract is also a trustless wrapper that accepts stETH tokens and mints
 * wstETH in return. Then the user unwraps, the contract burns user's wstETH
 * and sends user locked stETH in return.
 *
 * The contract provides the staking shortcut: user can send ETH with regular
 * transfer and get wstETH in return. The contract will send ETH to Lido submit
 * method, staking it and wrapping the received stETH.
 *
 */
contract PufETH is ERC20Permit {
    mapping(address => uint256) public ethShares;
    uint256 public totalETHShares;

    IPufferPool public pufferPool;
    IWithdrawalPool public withdrawalPool;
    IStETHVault public stETHVault;
    IPufETHVault public rPufETHVault;

    bool public isMainnet = false;

    // Input assets
    IStETH public constant stETH =
        IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IUSDC public constant USDC =
        IUSDC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IUSDT public constant USDT =
        IUSDT(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    IEigenLayer public constant EIGENLAYER =
        IEigenLayer(0xdAC17F958D2ee523a2206206994597C13D831ec7); // todo

    uint256 MAX_APPROVAL = ~uint256(0);

    // Swap protocols
    // IUniswap public constant USDC_STETH = IUniswap(...);

    event ETHDeposited(address indexed user, uint256 shares, uint256 amount);
    event USDDeposited(
        address indexed user,
        uint256 shares,
        uint256 amount,
        uint256 daiAmount
    );

    constructor()
        ERC20Permit("PufETH liquid restaking token")
        ERC20("PufETH liquid restaking token", "pufETH")
    {
        stETH.approve(address(EIGENLAYER), MAX_APPROVAL);
    }

    function setPufferPool(address a) external {
        pufferPool = IPufferPool(a);
    }

    function setWithdrawalPool(address a) external {
        withdrawalPool = IWithdrawalPool(a);
    }

    function setStETHVault(address a) external {
        stETHVault = IStETHVault(a);
        stETH.approve(address(stETHVault), MAX_APPROVAL);
    }

    function setRPufETHVault(address a) external {
        rPufETHVault = IPufETHVault(a);
        stETH.approve(address(rPufETHVault), MAX_APPROVAL);
    }

    /**
     * @notice Deposit stETH into stETHVault and mint pufETH
     * @param _stETHAmount amount of stETH to deposit in exchange for pufETH
     * @dev Requirements:
     *  - `_stETHAmount` must be non-zero
     *  - msg.sender must approve at least `_stETHAmount` stETH to this
     *    contract.
     *  - msg.sender must have at least `_stETHAmount` of stETH.
     * User should first approve _stETHAmount to the pufETH contract
     * @return Amount of pufETH user receives after wrap
     */
    function depositStETH(uint256 _stETHAmount) external returns (uint256) {
        require(_stETHAmount > 0, "insufficient stETH amount");
        if (isMainnet) {} else {
            uint256 pufETHAmount = stETH.getSharesByPooledEth(_stETHAmount);
            _mint(msg.sender, pufETHAmount);
            stETH.transferFrom(msg.sender, address(stETHVault), _stETHAmount);
            return pufETHAmount;
        }
    }

    /**
     * @notice Get amount of pufETH for a given amount of stETH
     * @param _stETHAmount amount of stETH
     * @return Amount of wstETH for a given stETH amount
     */
    function getPufETHByStETH(
        uint256 _stETHAmount
    ) external view returns (uint256) {
        return stETH.getSharesByPooledEth(_stETHAmount);
    }

    /**
     * @notice Get amount of stETH for a given amount of pufETH
     * @param _pufETHAmount amount of pufETH
     * @return Amount of stETH for a given pufETH amount
     */
    function getStETHByPufETH(
        uint256 _pufETHAmount
    ) external view returns (uint256) {
        return stETH.getPooledEthByShares(_pufETHAmount);
    }

    /**
     * @notice Get amount of stETH for a one pufETH
     * @return Amount of stETH for 1 pufETH
     */
    function stEthPerToken() external view returns (uint256) {
        return stETH.getPooledEthByShares(1 ether);
    }

    /**
     * @notice Get amount of pufETH for a one stETH
     * @return Amount of pufETH for a 1 stETH
     */
    function tokensPerStEth() external view returns (uint256) {
        return stETH.getSharesByPooledEth(1 ether);
    }

    // Performs Swap from ETH to stETH
    function depositETH(uint256 amount) external returns (uint256) {
        // swap

        // deposit

        // mint
        return 1;
    }

    // Performs Swap from USDC to stETH
    function depositUSDC(uint256 amount) external returns (uint256) {
        // swap

        // deposit

        // mint
        return 1;
    }

    // Performs Swap from USDC to stETH
    function depositUSDT(uint256 amount) external returns (uint256) {
        // swap

        // deposit

        // mint
        return 1;
    }

    // Deposit stETH for EigenPoints
    function depositToEigenLayer(uint256 amount) external returns (uint256) {
        return stETHVault.depositToEigenLayer(amount);
    }

    // Retrieve stETH from EigenLayer
    function withdrawFromEigenLayer(uint256 amount) external returns (uint256) {
        return 1;
    }

    // Trigger redemptions from Lido
    function requestLidoWithdrawal(uint256 amount) external returns (uint256) {
        return 1;
    }

    // Trigger redemptions from Lido
    function withdrawStETHToETH(uint256 amount) external returns (uint256) {
        return 1;
    }
}
