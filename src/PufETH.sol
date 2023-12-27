// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import { ERC20 } from "openzeppelin/token/ERC20/ERC20.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { ERC20Permit } from "openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import { IERC20Permit } from "openzeppelin/token/ERC20/extensions/IERC20Permit.sol";

import { IPufferPool } from "src/interface/IPufferPool.sol";
import { IWithdrawalPool } from "src/interface/IWithdrawalPool.sol";
import { IPufETHVault } from "src/interface/IPufETHVault.sol";
import { IStETHVault } from "src/interface/IStETHVault.sol";
import { IStETH } from "src/interface/IStETH.sol";
import { IStETHVault } from "src/interface/IStETHVault.sol";
import { IUSDC } from "src/interface/IUSDC.sol";
import { IUSDT } from "src/interface/IUSDT.sol";
import { ILidoWithdrawalQueue } from "src/interface/ILidoWithdrawalQueue.sol";
import { IEigenLayer } from "src/interface/IEigenLayer.sol";

contract PufETH is ERC20Permit {
    mapping(address => uint256) public ethShares;
    uint256 public totalETHShares;

    IPufferPool public pufferPool;
    IWithdrawalPool public withdrawalPool;
    IStETHVault public stETHVault;
    IPufETHVault public rPufETHVault;

    bool public isMainnet = false;

    // Input assets
    IStETH public constant stETH = IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    ILidoWithdrawalQueue public constant LidoWithdrawalQueue = ILidoWithdrawalQueue(address(0x00)); // todo
    IUSDC public constant USDC = IUSDC(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IUSDT public constant USDT = IUSDT(0xdAC17F958D2ee523a2206206994597C13D831ec7);

    IEigenLayer public constant EIGENLAYER = IEigenLayer(0xdAC17F958D2ee523a2206206994597C13D831ec7); // todo

    uint256 MAX_APPROVAL = ~uint256(0);

    // Swap protocols
    // IUniswap public constant USDC_STETH = IUniswap(...);

    event ETHDeposited(address indexed user, uint256 shares, uint256 amount);
    event USDDeposited(address indexed user, uint256 shares, uint256 amount, uint256 daiAmount);

    constructor() ERC20Permit("PufETH liquid restaking token") ERC20("PufETH liquid restaking token", "pufETH") { }

    function transitionMainnet() external {
        // todo onlyOwner
        isMainnet = true;
        // todo event
    }

    function setPufferPool(address a) external {
        // todo onlyOwner
        // todo only callable once
        pufferPool = IPufferPool(a);
        // todo event
    }

    function setWithdrawalPool(address a) external {
        // todo onlyOwner
        // todo only callable once
        withdrawalPool = IWithdrawalPool(a);
        // todo event
    }

    function setStETHVault(address a) external {
        // todo onlyOwner
        // todo only callable once
        stETHVault = IStETHVault(a);
        stETH.approve(address(stETHVault), MAX_APPROVAL);
        // todo event
    }

    function setRPufETHVault(address a) external {
        // todo onlyOwner
        // todo only callable once
        rPufETHVault = IPufETHVault(a);
        stETH.approve(address(rPufETHVault), MAX_APPROVAL);
        // todo event
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
        if (isMainnet) {
            // todo
        } else {
            // uint256 pufETHAmount = stETH.getSharesByPooledEth(_stETHAmount);
            uint256 pufETHAmount = getPufETHByReserve(_stETHAmount);
            _mint(msg.sender, pufETHAmount);
            stETH.transferFrom(msg.sender, address(stETHVault), _stETHAmount);
            return pufETHAmount;
        }
    }

    /**
     * @notice Get amount of pufETH for a given amount of the reserve token
     * @param _stETHAmount amount of stETH
     * @return Amount of pufETH for a given stETH amount
     */
    function getPufETHByReserve(uint256 _stETHAmount) public view returns (uint256) {
        if (isMainnet) {
            // todo
        } else {
            return stETH.getSharesByPooledEth(_stETHAmount);
        }
    }

    /**
     * @notice Get amount of stETH for a given amount of pufETH
     * @param _pufETHAmount amount of pufETH
     * @return Amount of stETH for a given pufETH amount
     */
    function getStETHByPufETH(uint256 _pufETHAmount) external view returns (uint256) {
        if (isMainnet) {
            // todo
        } else {
            return stETH.getPooledEthByShares(_pufETHAmount);
        }
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

    // // Deposit stETH for EigenPoints
    // function depositToEigenLayer(uint256 amount) external returns (uint256) {
    //     return stETHVault.depositToEigenLayer(amount);
    // }

    // // Retrieve stETH from EigenLayer
    // function withdrawFromEigenLayer(uint256 amount) external returns (uint256) {
    //     return stETHVault.withdrawFromEigenLayer(amount);
    // }
}
