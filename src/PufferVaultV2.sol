// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { PufferVault } from "./PufferVault.sol";
import { IStETH } from "./interface/Lido/IStETH.sol";
import { ILidoWithdrawalQueue } from "./interface/Lido/ILidoWithdrawalQueue.sol";
import { IEigenLayer } from "./interface/EigenLayer/IEigenLayer.sol";
import { IStrategy } from "./interface/EigenLayer/IStrategy.sol";
import { IWETH } from "./interface/Other/IWETH.sol";
import { IPufferOracle } from "./interface/IPufferOracle.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title PufferVaultV2
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
contract PufferVaultV2 is PufferVault {
    using SafeERC20 for address;

    /**
     * @dev Thrown if the Vault doesn't have ETH liquidity to transfer to PufferModule
     */
    error ETHTransferFailed();

    /**
     * Emitted when the daily withdrawal limit is set
     * @dev Signature: 0x8d5f7487ce1fd25059bd15204a55ea2c293160362b849a6f9244aec7d5a3700b
     */
    event DailyWithdrawalLimitSet(uint96 oldLimit, uint96 newLimit);

    /**
     * Emitted when the Vault transfers ETH to a specified address
     * @dev Signature: 0xba7bb5aa419c34d8776b86cc0e9d41e72d74a893a511f361a11af6c05e920c3d
     */
    event TransferredETH(address indexed to, uint256 amount);

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

    // solhint-disable-next-line no-complex-fallback
    receive() external payable virtual override {
        // If we don't use this pattern, somebody can create a Lido withdrawal, claim it to this contract
        // Making `$.lidoLockedETH -= msg.value` revert
        VaultStorage storage $ = _getPufferVaultStorage();
        if ($.isLidoWithdrawal) {
            $.lidoLockedETH -= msg.value;
        }
    }

    /**
     * @notice Changes token from stETH to WETH
     */
    function initialize() public reinitializer(2) {
        // In this initialization, we swap out the underlying stETH with WETH
        ERC4626Storage storage erc4626Storage = _getERC4626StorageInternal();
        erc4626Storage._asset = _WETH;
        _setDailyWithdrawalLimit(100 ether);
        _updateDailyWithdrawals(0);
    }

    /**
     * @dev See {IERC4626-totalAssets}.
     * Eventually, stETH will not exist anymore, and the Vault will represent shares of total ETH holdings
     * ETH to stETH is always 1:1 (stETH is rebasing token)
     * Sum of EL assets + Vault Assets
     *
     * NOTE on the native ETH deposit:
     * When dealing with NATIVE ETH deposits, we need to deduct callvalue from the balance.
     * The contract calculates the amount of shares(pufETH) to mint based on the total assets.
     * When a user sends ETH, the msg.value is immediately added to address(this).balance, and address(this.balance) is included in the total assets.
     * Because of that we must deduct the callvalue from the balance to avoid the user getting more shares than he should.
     * We can't use msg.value in a view function, so we use assembly to get the callvalue.
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
     * @notice Calculates the maximum amount of assets that can be withdrawn by the `owner`.
     * @dev This function considers both the remaining daily withdrawal limit and the `owner`'s balance.
     * @param owner The address of the owner for which the maximum withdrawal amount is calculated.
     * @return maxAssets The maximum amount of assets that can be withdrawn by the `owner`.
     */
    function maxWithdraw(address owner) public view virtual override returns (uint256 maxAssets) {
        uint256 remainingAssets = getRemainingAssetsDailyWithdrawalLimit();
        uint256 maxUserAssets = previewRedeem(balanceOf(owner));
        return remainingAssets < maxUserAssets ? remainingAssets : maxUserAssets;
    }

    /**
     * @notice Calculates the maximum amount of shares that can be redeemed by the `owner`.
     * @dev This function considers both the remaining daily withdrawal limit in terms of assets and converts it to shares, and the `owner`'s share balance.
     * @param owner The address of the owner for which the maximum redeemable shares are calculated.
     * @return maxShares The maximum amount of shares that can be redeemed by the `owner`.
     */
    function maxRedeem(address owner) public view virtual override returns (uint256 maxShares) {
        uint256 remainingShares = previewWithdraw(getRemainingAssetsDailyWithdrawalLimit());
        uint256 userShares = balanceOf(owner);
        return remainingShares < userShares ? remainingShares : userShares;
    }

    /**
     * @notice Withdrawals are allowed if the asset out is WETH
     * @dev Restricted in this context is like `whenNotPaused` modifier from Pausable.sol
     * Copied the original ERC4626 code back to override `PufferVault` + wrap ETH logic
     */
    function withdraw(uint256 assets, address receiver, address owner)
        public
        virtual
        override
        restricted
        returns (uint256)
    {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        _updateDailyWithdrawals(assets);

        _wrapETH(assets);

        uint256 shares = previewWithdraw(assets);
        // solhint-disable-next-line func-named-parameters
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    /**
     * @notice Withdrawals are allowed an the asset out is WETH
     * @dev Restricted in this context is like `whenNotPaused` modifier from Pausable.sol
     * Copied the original ERC4626 code back to override `PufferVault` + wrap ETH logic
     */
    function redeem(uint256 shares, address receiver, address owner)
        public
        virtual
        override
        restricted
        returns (uint256)
    {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        uint256 assets = previewRedeem(shares);

        _updateDailyWithdrawals(assets);

        _wrapETH(assets);

        // solhint-disable-next-line func-named-parameters
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    /**
     * @notice Deposits native ETH
     * @dev Restricted in this context is like `whenNotPaused` modifier from Pausable.sol
     */
    function depositETH(address receiver) public payable virtual restricted returns (uint256) {
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
     * @notice Deposits stETH
     * @dev Restricted in this context is like `whenNotPaused` modifier from Pausable.sol
     */
    function depositStETH(uint256 assets, address receiver) public virtual restricted returns (uint256) {
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
     * @notice Transfers ETH to a specified address
     * @dev Restricted to PufferProtocol smart contract
     * We use it to transfer ETH to PufferModule
     * @param to The address of the module to transfer ETH to
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
     * @notice Allows the `msg.sender` to burn his shares
     * @dev Restricted in this context is like `whenNotPaused` modifier from Pausable.sol
     * We use it to burn the bond if the node operator gets slashed
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
     * @notice Returns the remaining assets that can be withdrawn today
     * @return The remaining assets that can be withdrawn today
     */
    function getRemainingAssetsDailyWithdrawalLimit() public view virtual returns (uint96) {
        VaultStorage storage $ = _getPufferVaultStorage();
        uint96 dailyAssetsWithdrawalLimit = $.dailyAssetsWithdrawalLimit;
        uint96 assetsWithdrawnToday = $.assetsWithdrawnToday;

        if (dailyAssetsWithdrawalLimit < assetsWithdrawnToday) {
            return 0;
        }
        return dailyAssetsWithdrawalLimit - assetsWithdrawnToday;
    }

    function _wrapETH(uint256 assets) internal {
        uint256 wethBalance = _WETH.balanceOf(address(this));

        if (wethBalance < assets) {
            _WETH.deposit{ value: assets - wethBalance }();
        }
    }

    /**
     * @param withdrawalAmount is the assets amount, not shares
     */
    function _updateDailyWithdrawals(uint256 withdrawalAmount) internal {
        VaultStorage storage $ = _getPufferVaultStorage();

        // Check if it's a new day to reset the withdrawal count
        if ($.lastWithdrawalDay < block.timestamp / 1 days) {
            $.lastWithdrawalDay = uint64(block.timestamp / 1 days);
            $.assetsWithdrawnToday = 0;
        }

        $.assetsWithdrawnToday += uint96(withdrawalAmount);
    }

    /**
     * @param newLimit is the assets amount, not shares
     */
    function _setDailyWithdrawalLimit(uint96 newLimit) internal {
        VaultStorage storage $ = _getPufferVaultStorage();
        emit DailyWithdrawalLimitSet($.dailyAssetsWithdrawalLimit, newLimit);
        $.dailyAssetsWithdrawalLimit = newLimit;
    }

    function _authorizeUpgrade(address newImplementation) internal virtual override restricted { }

    function _getERC4626StorageInternal() internal pure returns (ERC4626Storage storage $) {
        // keccak256(abi.encode(uint256(keccak256("openzeppelin.storage.ERC4626")) - 1)) & ~bytes32(uint256(0xff))
        // solhint-disable-next-line no-inline-assembly
        assembly {
            $.slot := 0x0773e532dfede91f04b12a73d3d2acd361424f41f76b4fb79f090161e36b4e00
        }
    }
}
