// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { PufferVault } from "./PufferVault.sol";
import { IStETH } from "./interface/Lido/IStETH.sol";
import { ILidoWithdrawalQueue } from "./interface/Lido/ILidoWithdrawalQueue.sol";
import { IEigenLayer } from "./interface/EigenLayer/IEigenLayer.sol";
import { IStrategy } from "./interface/EigenLayer/IStrategy.sol";
import { IWETH } from "./interface/Other/IWETH.sol";
import { IPufferVaultV2 } from "./interface/IPufferVaultV2.sol";
import { IPufferOracle } from "./interface/IPufferOracle.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EnumerableMap } from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title PufferVaultV2
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
contract PufferVaultV2 is PufferVault, IPufferVaultV2 {
    using SafeERC20 for address;
    using EnumerableMap for EnumerableMap.UintToUintMap;
    using Math for uint256;

    uint256 private constant _BASIS_POINT_SCALE = 1e4;

    /**
     * @dev The Wrapped Ethereum ERC20 token
     */
    IWETH internal immutable _WETH;

    /**
     * @dev The PufferOracle contract
     */
    IPufferOracle public immutable PUFFER_ORACLE;

    constructor(
        IStETH stETH,
        IWETH weth,
        ILidoWithdrawalQueue lidoWithdrawalQueue,
        IStrategy stETHStrategy,
        IEigenLayer eigenStrategyManager,
        IPufferOracle oracle
    ) PufferVault(stETH, lidoWithdrawalQueue, stETHStrategy, eigenStrategyManager) {
        _WETH = weth;
        PUFFER_ORACLE = oracle;
        _disableInitializers();
    }

    receive() external payable virtual override { }

    /**
     * @notice Changes underlying asset from stETH to WETH
     */
    function initialize() public reinitializer(2) {
        // In this initialization, we swap out the underlying stETH with WETH
        ERC4626Storage storage erc4626Storage = _getERC4626StorageInternal();
        erc4626Storage._asset = _WETH;
        _setDailyWithdrawalLimit(100 ether);
        _updateDailyWithdrawals(0);
        _setExitFeeBasisPoints(100); // 1%
    }

    /**
     * @dev See {IERC4626-totalAssets}.
     * pufETH, the shares of the vault, will be backed primarily by the WETH asset.
     * However, at any point in time, the full backings may be a combination of stETH, WETH, and ETH.
     * `totalAssets()` is calculated by summing the following:
     * - WETH held in the vault contract
     * - ETH  held in the vault contract
     * - PUFFER_ORACLE.getLockedEthAmount(), which is the oracle-reported Puffer validator ETH locked in the Beacon chain
     * - stETH held in the vault contract, in EigenLayer's stETH strategy, and in Lido's withdrawal queue. (we assume stETH is always 1:1 with ETH since it's rebasing)
     *
     * NOTE on the native ETH deposits:
     * When dealing with NATIVE ETH deposits, we need to deduct callvalue from the balance.
     * The contract calculates the amount of shares(pufETH) to mint based on the total assets.
     * When a user sends ETH, the msg.value is immediately added to address(this).balance.
     * Since address(this.balance)` is used in calculating `totalAssets()`, we must deduct the `callvalue()` from the balance to prevent the user from minting excess shares.
     * `msg.value` cannot be accessed from a view function, so we use assembly to get the callvalue.
     */
    function totalAssets() public view virtual override returns (uint256) {
        uint256 callValue;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            callValue := callvalue()
        }
        return _ST_ETH.balanceOf(address(this)) + getPendingLidoETHAmount() + getELBackingEthAmount()
            + _WETH.balanceOf(address(this)) + (address(this).balance - callValue) + PUFFER_ORACLE.getLockedEthAmount();
    }

    /**
     * @notice Withdrawals WETH assets from the vault, burning the `owner`'s (pufETH) shares.
     * The caller of this function does not have to be the `owner` if the `owner` has approved the caller to spend their pufETH.
     * @dev Restricted in this context is like `whenNotPaused` modifier from Pausable.sol
     * Copied the original ERC4626 code back to override `PufferVault` + wrap ETH logic
     * @param assets The amount of assets (WETH) to withdraw
     * @param receiver The address to receive the assets (WETH)
     * @param owner The address of the owner for which the shares (pufETH) are burned.
     * @return shares The amount of shares (pufETH) burned
     */
    function withdraw(uint256 assets, address receiver, address owner)
        public
        virtual
        override
        restricted
        returns (uint256)
    {
        _revertIfDeposited();
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        _updateDailyWithdrawals(assets);

        _wrapETH(assets);

        uint256 shares = previewWithdraw(assets);
        _withdraw({ caller: _msgSender(), receiver: receiver, owner: owner, assets: assets, shares: shares });

        return shares;
    }

    /**
     * @notice Redeems (pufETH) `shares` to receive (WETH) assets from the vault, burning the `owner`'s (pufETH) `shares`.
     * The caller of this function does not have to be the `owner` if the `owner` has approved the caller to spend their pufETH.
     * @dev Restricted in this context is like `whenNotPaused` modifier from Pausable.sol
     * Copied the original ERC4626 code back to override `PufferVault` + wrap ETH logic
     * @param shares The amount of shares (pufETH) to withdraw
     * @param receiver The address to receive the assets (WETH)
     * @param owner The address of the owner for which the shares (pufETH) are burned.
     * @return assets The amount of assets (WETH) redeemed
     */
    function redeem(uint256 shares, address receiver, address owner)
        public
        virtual
        override
        restricted
        returns (uint256)
    {
        _revertIfDeposited();
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        uint256 assets = previewRedeem(shares);

        _updateDailyWithdrawals(assets);

        _wrapETH(assets);

        _withdraw({ caller: _msgSender(), receiver: receiver, owner: owner, assets: assets, shares: shares });

        return assets;
    }

    /**
     * @inheritdoc IPufferVaultV2
     * @dev Restricted in this context is like `whenNotPaused` modifier from Pausable.sol
     */
    function depositETH(address receiver) public payable virtual restricted returns (uint256) {
        _markDeposit();

        uint256 maxAssets = maxDeposit(receiver);
        if (msg.value > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, msg.value, maxAssets);
        }

        uint256 shares = previewDeposit(msg.value);
        _mint(receiver, shares);
        emit Deposit(_msgSender(), receiver, msg.value, shares);

        return shares;
    }

    /**
     * @inheritdoc IPufferVaultV2
     * @dev Restricted in this context is like `whenNotPaused` modifier from Pausable.sol
     */
    function depositStETH(uint256 assets, address receiver) public virtual restricted returns (uint256) {
        _markDeposit();

        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }

        uint256 shares = previewDeposit(assets);

        // slither-disable-next-line reentrancy-no-eth
        SafeERC20.safeTransferFrom(_ST_ETH, _msgSender(), address(this), assets);
        _mint(receiver, shares);

        emit Deposit(_msgSender(), receiver, assets, shares);

        return shares;
    }

    /**
     * @inheritdoc PufferVault
     * @dev Restricted in this context is like `whenNotPaused` modifier from Pausable.sol
     */
    function deposit(uint256 assets, address receiver) public virtual override restricted returns (uint256) {
        _markDeposit();
        return super.deposit(assets, receiver);
    }

    /**
     * @inheritdoc PufferVault
     * @dev Restricted in this context is like `whenNotPaused` modifier from Pausable.sol
     */
    function mint(uint256 shares, address receiver) public override restricted returns (uint256) {
        _markDeposit();
        return super.mint(shares, receiver);
    }

    /**
     * @notice Initiates ETH withdrawals from Lido
     * @dev Restricted to Operations Multisig
     * @param amounts An array of stETH amounts to queue
     * @return requestIds An array of request IDs for the withdrawals
     */
    function initiateETHWithdrawalsFromLido(uint256[] calldata amounts)
        external
        virtual
        override
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

        for (uint256 i = 0; i < requestIds.length; ++i) {
            $.lidoWithdrawalAmounts.set(requestIds[i], amounts[i]);
        }
        emit RequestedWithdrawals(requestIds);
        return requestIds;
    }

    /**
     * @notice Claims ETH withdrawals from Lido
     * @dev Restricted to Operations Multisig
     * @param requestIds An array of request IDs for the withdrawals
     */
    function claimWithdrawalsFromLido(uint256[] calldata requestIds) external virtual override restricted {
        VaultStorage storage $ = _getPufferVaultStorage();

        // ETH balance before the claim
        uint256 balanceBefore = address(this).balance;

        uint256 expectedWithdrawal = 0;

        for (uint256 i = 0; i < requestIds.length; ++i) {
            // .get reverts if requestId is not present
            expectedWithdrawal += $.lidoWithdrawalAmounts.get(requestIds[i]);

            // slither-disable-next-line calls-loop
            _LIDO_WITHDRAWAL_QUEUE.claimWithdrawal(requestIds[i]);
        }

        // ETH balance after the claim
        uint256 balanceAfter = address(this).balance;
        uint256 actualWithdrawal = balanceAfter - balanceBefore;
        // Deduct from the locked amount the expected amount
        $.lidoLockedETH -= expectedWithdrawal;

        emit ClaimedWithdrawals(requestIds);
        emit LidoWithdrawal(expectedWithdrawal, actualWithdrawal);
    }

    /**
     * @notice Transfers ETH to a specified address.
     * @dev Restricted to PufferProtocol smart contract
     * @dev It is used to transfer ETH to PufferModules to fund Puffer validators.
     * @param to The address of the PufferModule to transfer ETH to
     * @param ethAmount The amount of ETH to transfer
     */
    function transferETH(address to, uint256 ethAmount) external restricted {
        // Our Vault holds ETH & WETH
        // If we don't have enough ETH for the transfer, unwrap WETH
        uint256 ethBalance = address(this).balance;
        if (ethBalance < ethAmount) {
            // Reverts if no WETH to unwrap
            _WETH.withdraw(ethAmount - ethBalance);
        }

        // slither-disable-next-line arbitrary-send-eth
        (bool success,) = to.call{ value: ethAmount }("");

        if (!success) {
            revert ETHTransferFailed();
        }

        emit TransferredETH(to, ethAmount);
    }

    /**
     * @notice Allows the `msg.sender` to burn their (pufETH) shares
     * @dev Restricted in this context is like `whenNotPaused` modifier from Pausable.sol
     * @dev It is used to burn portions of Puffer validator bonds due to inactivity or slashing
     * @param shares The amount of shares to burn
     */
    function burn(uint256 shares) public restricted {
        _burn(msg.sender, shares);
    }

    /**
     * @notice Sets a new daily withdrawal limit
     * @dev Restricted to the DAO
     * @param newLimit The new daily limit to be set
     */
    function setDailyWithdrawalLimit(uint96 newLimit) external restricted {
        _setDailyWithdrawalLimit(newLimit);
    }

    /**
     * @param newExitFeeBasisPoints is the new exit fee basis points
     * @dev Restricted to the DAO
     */
    function setExitFeeBasisPoints(uint256 newExitFeeBasisPoints) external restricted {
        _setExitFeeBasisPoints(newExitFeeBasisPoints);
    }

    /**
     * @inheritdoc IPufferVaultV2
     */
    function getRemainingAssetsDailyWithdrawalLimit() public view virtual returns (uint256) {
        VaultStorage storage $ = _getPufferVaultStorage();
        uint96 dailyAssetsWithdrawalLimit = $.dailyAssetsWithdrawalLimit;
        uint96 assetsWithdrawnToday = $.assetsWithdrawnToday;

        if (dailyAssetsWithdrawalLimit < assetsWithdrawnToday) {
            return 0;
        }

        // If we are in a new day, return the full daily limit
        if ($.lastWithdrawalDay < block.timestamp / 1 days) {
            return dailyAssetsWithdrawalLimit;
        }

        return dailyAssetsWithdrawalLimit - assetsWithdrawnToday;
    }

    /**
     * @notice Calculates the maximum amount of assets (WETH) that can be withdrawn by the `owner`.
     * @dev This function considers both the remaining daily withdrawal limit and the `owner`'s balance.
     * See {IERC4626-maxWithdraw}
     * @param owner The address of the owner for which the maximum withdrawal amount is calculated.
     * @return maxAssets The maximum amount of assets that can be withdrawn by the `owner`.
     */
    function maxWithdraw(address owner) public view virtual override returns (uint256 maxAssets) {
        uint256 remainingAssets = getRemainingAssetsDailyWithdrawalLimit();
        uint256 maxUserAssets = previewRedeem(balanceOf(owner));
        return remainingAssets < maxUserAssets ? remainingAssets : maxUserAssets;
    }

    /**
     * @notice Calculates the maximum amount of shares (pufETH) that can be redeemed by the `owner`.
     * @dev This function considers both the remaining daily withdrawal limit in terms of assets and converts it to shares, and the `owner`'s share balance.
     * See {IERC4626-maxRedeem}
     * @param owner The address of the owner for which the maximum redeemable shares are calculated.
     * @return maxShares The maximum amount of shares that can be redeemed by the `owner`.
     */
    function maxRedeem(address owner) public view virtual override returns (uint256 maxShares) {
        uint256 remainingShares = previewWithdraw(getRemainingAssetsDailyWithdrawalLimit());
        uint256 userShares = balanceOf(owner);
        return remainingShares < userShares ? remainingShares : userShares;
    }

    /**
     * @dev Preview adding an exit fee on withdraw. See {IERC4626-previewWithdraw}.
     */
    function previewWithdraw(uint256 assets) public view virtual override returns (uint256) {
        uint256 fee = _feeOnRaw(assets, getExitFeeBasisPoints());
        return super.previewWithdraw(assets + fee);
    }

    /**
     * @dev Preview taking an exit fee on redeem. See {IERC4626-previewRedeem}.
     */
    function previewRedeem(uint256 shares) public view virtual override returns (uint256) {
        uint256 assets = super.previewRedeem(shares);
        return assets - _feeOnTotal(assets, getExitFeeBasisPoints());
    }

    /**
     * @inheritdoc IPufferVaultV2
     */
    function getExitFeeBasisPoints() public view virtual returns (uint256) {
        VaultStorage storage $ = _getPufferVaultStorage();
        return $.exitFeeBasisPoints;
    }

    /**
     * @dev Calculates the fees that should be added to an amount `assets` that does not already include fees.
     * Used in {IERC4626-withdraw}.
     */
    function _feeOnRaw(uint256 assets, uint256 feeBasisPoints) internal pure virtual returns (uint256) {
        return assets.mulDiv(feeBasisPoints, _BASIS_POINT_SCALE, Math.Rounding.Ceil);
    }

    /**
     * @dev Calculates the fee part of an amount `assets` that already includes fees.
     * Used in {IERC4626-redeem}.
     */
    function _feeOnTotal(uint256 assets, uint256 feeBasisPoints) internal pure virtual returns (uint256) {
        return assets.mulDiv(feeBasisPoints, feeBasisPoints + _BASIS_POINT_SCALE, Math.Rounding.Ceil);
    }

    /**
     * @notice Wraps the vault's ETH balance to WETH.
     * @dev Used to provide WETH liquidity
     */
    function _wrapETH(uint256 assets) internal virtual {
        uint256 wethBalance = _WETH.balanceOf(address(this));

        if (wethBalance < assets) {
            _WETH.deposit{ value: assets - wethBalance }();
        }
    }

    /**
     * @notice Updates the amount of assets (WETH) withdrawn today
     * @param withdrawalAmount is the assets (WETH) amount
     */
    function _updateDailyWithdrawals(uint256 withdrawalAmount) internal virtual {
        VaultStorage storage $ = _getPufferVaultStorage();

        // Check if it's a new day to reset the withdrawal count
        if ($.lastWithdrawalDay < block.timestamp / 1 days) {
            $.lastWithdrawalDay = uint64(block.timestamp / 1 days);
            $.assetsWithdrawnToday = 0;
        }
        $.assetsWithdrawnToday += uint96(withdrawalAmount);
        emit AssetsWithdrawnToday($.assetsWithdrawnToday);
    }

    /**
     * @notice Updates the maximum amount of assets (WETH) that can be withdrawn daily
     * @param newLimit is the assets (WETH) amount
     */
    function _setDailyWithdrawalLimit(uint96 newLimit) internal virtual {
        VaultStorage storage $ = _getPufferVaultStorage();
        emit DailyWithdrawalLimitSet($.dailyAssetsWithdrawalLimit, newLimit);
        $.dailyAssetsWithdrawalLimit = newLimit;
    }

    /**
     * @notice Updates the exit fee basis points
     * @dev 200 Basis points = 2% is the maximum exit fee
     */
    function _setExitFeeBasisPoints(uint256 newExitFeeBasisPoints) internal virtual {
        VaultStorage storage $ = _getPufferVaultStorage();
        // 2% is the maximum exit fee
        if (newExitFeeBasisPoints > 200) {
            revert InvalidExitFeeBasisPoints();
        }
        emit ExitFeeBasisPointsSet($.exitFeeBasisPoints, newExitFeeBasisPoints);
        $.exitFeeBasisPoints = newExitFeeBasisPoints;
    }

    // slither-disable-next-line dead-code
    function _markDeposit() internal virtual {
        assembly {
            tstore(_DEPOSIT_TRACKER_LOCATION, 1)
        }
    }

    function _revertIfDeposited() internal virtual {
        assembly {
            if tload(_DEPOSIT_TRACKER_LOCATION) {
                mstore(0x00, 0x39b79d11) // `DepositAndWithdrawalForbidden()`.
                revert(0x1c, 0x04)
            }
        }
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override restricted { }

    function _getERC4626StorageInternal() private pure returns (ERC4626Storage storage $) {
        // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC4626")) - 1)) & ~bytes32(uint256(0xff))
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := 0x0773e532dfede91f04b12a73d3d2acd361424f41f76b4fb79f090161e36b4e00
        }
    }
}
