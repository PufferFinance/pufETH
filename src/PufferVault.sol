// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { IPufferVault } from "src/interface/IPufferVault.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { IStETH } from "src/interface/Lido/IStETH.sol";
import { ILidoWithdrawalQueue } from "src/interface/Lido/ILidoWithdrawalQueue.sol";
import { IEigenLayer } from "src/interface/EigenLayer/IEigenLayer.sol";
import { IStrategy } from "src/interface/EigenLayer/IStrategy.sol";
import { PufferVaultStorage } from "src/PufferVaultStorage.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { UUPSUpgradeable } from "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessManagedUpgradeable } from
    "@openzeppelin-contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import { ERC4626Upgradeable } from "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

/**
 * @title PufferVault
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
contract PufferVault is
    IPufferVault,
    IERC721Receiver,
    PufferVaultStorage,
    AccessManagedUpgradeable,
    ERC4626Upgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for address;

    /**
     * @dev EigenLayer stETH strategy
     */
    IStrategy internal immutable _EIGEN_STETH_STRATEGY;
    /**
     * @dev EigenLayer Strategy Manager
     */
    IEigenLayer internal immutable _EIGEN_STRATEGY_MANAGER;
    /**
     * @dev stETH contract
     */
    IStETH internal immutable _ST_ETH;
    /**
     * @dev Lido Withdrawal Queue
     */
    ILidoWithdrawalQueue internal immutable _LIDO_WITHDRAWAL_QUEUE;

    constructor(
        IStETH stETH,
        ILidoWithdrawalQueue lidoWithdrawalQueue,
        IStrategy stETHStrategy,
        IEigenLayer eigenStrategyManager
    ) payable {
        _ST_ETH = stETH;
        _LIDO_WITHDRAWAL_QUEUE = lidoWithdrawalQueue;
        _EIGEN_STETH_STRATEGY = stETHStrategy;
        _EIGEN_STRATEGY_MANAGER = eigenStrategyManager;
        _disableInitializers();
    }

    function initialize(address accessManager) external initializer {
        __AccessManaged_init(accessManager);
        __ERC4626_init(_ST_ETH);
        __ERC20_init("pufETH", "pufETH");
    }

    receive() external payable virtual {
        // If we don't use this pattern, somebody can create a Lido withdrawal, claim it to this contract
        // Making `$.lidoLockedETH -= msg.value` revert
        VaultStorage storage $ = _getPufferVaultStorage();
        if ($.isLidoWithdrawal) {
            $.lidoLockedETH -= msg.value;
        }
    }

    /**
     * @notice Claims ETH withdrawals from Lido
     * @param requestIds An array of request IDs for the withdrawals
     */
    function claimWithdrawalsFromLido(uint256[] calldata requestIds) external virtual {
        VaultStorage storage $ = _getPufferVaultStorage();

        // Tell our receive() that we are doing a Lido claim
        $.isLidoWithdrawal = true;

        for (uint256 i = 0; i < requestIds.length; ++i) {
            // slither-disable-next-line calls-loop
            _LIDO_WITHDRAWAL_QUEUE.claimWithdrawal(requestIds[i]);
        }

        // Reset back the value
        $.isLidoWithdrawal = false;
        emit ClaimedWithdrawals(requestIds);
    }

    /**
     * @notice Not allowed
     */
    function redeem(uint256, address, address) public virtual override returns (uint256) {
        revert WithdrawalsAreDisabled();
    }

    /**
     * @notice Not allowed
     */
    function withdraw(uint256, address, address) public virtual override returns (uint256) {
        revert WithdrawalsAreDisabled();
    }

    /**
     * @dev See {IERC4626-totalAssets}.
     * Eventually, stETH will not be part of this vault anymore, and the Vault(pufETH) will represent shares of total ETH holdings
     * Because stETH is a rebasing token, its ratio with ETH is 1:1
     * Because of that our ETH holdings backing the system are:
     * stETH balance of this vault + stETH balance locked in EigenLayer + stETH balance that is the process of withdrawal from Lido
     * + ETH balance of this vault
     */
    function totalAssets() public view virtual override returns (uint256) {
        return _ST_ETH.balanceOf(address(this)) + getELBackingEthAmount() + getPendingLidoETHAmount()
            + address(this).balance;
    }

    /**
     * @notice Returns the ETH amount that is backing this vault locked in EigenLayer stETH strategy
     */
    function getELBackingEthAmount() public view virtual returns (uint256 ethAmount) {
        VaultStorage storage $ = _getPufferVaultStorage();
        // When we initiate withdrawal from EigenLayer, the shares are deducted from the `lockedAmount`
        // In that case the locked amount goes to 0 and the pendingWithdrawalAmount increases
        uint256 lockedAmount = _EIGEN_STETH_STRATEGY.userUnderlying(address(this));
        uint256 pendingWithdrawalAmount =
            _EIGEN_STETH_STRATEGY.sharesToUnderlyingView($.eigenLayerPendingWithdrawalSharesAmount);
        return lockedAmount + pendingWithdrawalAmount;
    }

    /**
     * @notice Returns the amount of ETH that is pending withdrawal from Lido
     * @return The amount of ETH pending withdrawal
     */
    function getPendingLidoETHAmount() public view virtual returns (uint256) {
        VaultStorage storage $ = _getPufferVaultStorage();
        return $.lidoLockedETH;
    }

    /**
     * @notice Deposits stETH into `stETH EigenLayer strategy`
     * Restricted access
     * @param amount the amount of stETH to deposit
     */
    function depositToEigenLayer(uint256 amount) external virtual restricted {
        SafeERC20.safeIncreaseAllowance(_ST_ETH, address(_EIGEN_STRATEGY_MANAGER), amount);
        _EIGEN_STRATEGY_MANAGER.depositIntoStrategy({ strategy: _EIGEN_STETH_STRATEGY, token: _ST_ETH, amount: amount });
    }

    /**
     * @notice Initiates stETH withdrawals from EigenLayer
     * Restricted access
     * @param sharesToWithdraw An amount of EigenLayer shares that we want to queue
     */
    function initiateStETHWithdrawalFromEigenLayer(uint256 sharesToWithdraw) external virtual restricted {
        VaultStorage storage $ = _getPufferVaultStorage();

        uint256[] memory strategyIndexes = new uint256[](1);
        strategyIndexes[0] = 0;

        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = IStrategy(_EIGEN_STETH_STRATEGY);

        uint256[] memory shares = new uint256[](1);
        shares[0] = sharesToWithdraw;

        // Account for the shares
        $.eigenLayerPendingWithdrawalSharesAmount += sharesToWithdraw;

        _EIGEN_STRATEGY_MANAGER.queueWithdrawal({
            strategyIndexes: strategyIndexes,
            strategies: strategies,
            shares: shares,
            withdrawer: address(this),
            undelegateIfPossible: true
        });
    }

    /**
     * @notice Claims stETH withdrawals from EigenLayer
     * Restricted access
     * @param queuedWithdrawal The queued withdrawal details
     * @param tokens The tokens to be withdrawn
     * @param middlewareTimesIndex The index of middleware times
     */
    function claimWithdrawalFromEigenLayer(
        IEigenLayer.QueuedWithdrawal calldata queuedWithdrawal,
        IERC20[] calldata tokens,
        uint256 middlewareTimesIndex
    ) external virtual {
        VaultStorage storage $ = _getPufferVaultStorage();

        $.eigenLayerPendingWithdrawalSharesAmount -= queuedWithdrawal.shares[0];

        _EIGEN_STRATEGY_MANAGER.completeQueuedWithdrawal({
            queuedWithdrawal: queuedWithdrawal,
            tokens: tokens,
            middlewareTimesIndex: middlewareTimesIndex,
            receiveAsTokens: true
        });
    }

    /**
     * @notice Initiates ETH withdrawals from Lido
     * Restricted access
     * @param amounts An array of amounts that we want to queue
     */
    function initiateETHWithdrawalsFromLido(uint256[] calldata amounts)
        external
        virtual
        restricted
        returns (uint256[] memory requestIds)
    {
        VaultStorage storage $ = _getPufferVaultStorage();

        uint256 lockedAmount;
        for (uint256 i = 0; i < amounts.length; ++i) {
            lockedAmount += amounts[i];
        }
        $.lidoLockedETH += lockedAmount;

        SafeERC20.safeIncreaseAllowance(_ST_ETH, address(_LIDO_WITHDRAWAL_QUEUE), lockedAmount);
        requestIds = _LIDO_WITHDRAWAL_QUEUE.requestWithdrawals(amounts, address(this));
        emit RequestedWithdrawals(requestIds);
        return requestIds;
    }

    /**
     * @notice Required by the ERC721 Standard
     */
    function onERC721Received(address, address, uint256, bytes calldata) external virtual returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    /**
     * @dev Authorizes an upgrade to a new implementation
     * Restricted access
     * @param newImplementation The address of the new implementation
     */
    // slither-disable-next-line dead-code
    function _authorizeUpgrade(address newImplementation) internal virtual override restricted { }
}
