// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { PufferVault } from "src/PufferVault.sol";
import { IStETH } from "src/interface/Lido/IStETH.sol";
import { ILidoWithdrawalQueue } from "src/interface/Lido/ILidoWithdrawalQueue.sol";
import { IEigenLayer } from "src/interface/EigenLayer/IEigenLayer.sol";
import { IStrategy } from "src/interface/EigenLayer/IStrategy.sol";
import { IWETH } from "src/interface/Other/IWETH.sol";

/**
 * @title PufferVault
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
contract PufferVaultMainnet is PufferVault {
    /**
     * Throws if the withdrawal will exceed daily withdrawal limit
     */
    error ExceededDailyWithdrawalLimit(uint256 dailyWithdrawalLimit, uint256 withdrawnToday, uint256 withdrawalAmount);

    /**
     * Emitted when the daily withdrawal limit is set
     * @dev Signature: 0x8d5f7487ce1fd25059bd15204a55ea2c293160362b849a6f9244aec7d5a3700b
     */
    event DailyWithdrawalLimitSet(uint96 oldLimit, uint96 newLimit);

    /**
     * @dev The Wrapped Ethereum ERC20 token
     */
    IWETH internal immutable _WETH;

    constructor(
        IStETH stETH,
        IWETH weth,
        ILidoWithdrawalQueue lidoWithdrawalQueue,
        IStrategy stETHStrategy,
        IEigenLayer eigenStrategyManager
    ) PufferVault(stETH, lidoWithdrawalQueue, stETHStrategy, eigenStrategyManager) {
        _ST_ETH = stETH;
        _WETH = weth;
        _LIDO_WITHDRAWAL_QUEUE = lidoWithdrawalQueue;
        _EIGEN_STETH_STRATEGY = stETHStrategy;
        _EIGEN_STRATEGY_MANAGER = eigenStrategyManager;
        _disableInitializers();
    }

    /**
     * @notice Changes token from stETH to WETH
     */
    function initialize() public reinitializer(2) {
        // In this initialization, we swap out the underlying stETH with WETH
        ERC4626Storage storage erc4626Storage = _getERC4626StorageInternal();
        erc4626Storage._asset = _WETH;

        VaultStorage storage $ = _getPufferVaultStorage();
        $.lastWithdrawalDay = uint64(block.timestamp / 1 days);
    }

    /**
     * @dev See {IERC4626-totalAssets}.
     * Eventually, stETH will not exist anymore, and the Vault will represent shares of total ETH holdings
     * ETH to stETH is always 1:1 (stETH is rebasing token)
     * Sum of EL assets + Vault Assets
     */
    function totalAssets() public view virtual override returns (uint256) {
        // If we are dealing with native ETH deposit, we need to deduct callvalue from the balance
        uint256 callValue;
        assembly {
            callValue := callvalue()
        }
        return _ST_ETH.balanceOf(address(this)) + getELBackingEthAmount() + _WETH.balanceOf(address(this))
            + (address(this).balance - callValue); //@todo when you add oracle pufferOracle.getLockedEthAmount()
    }

    /**
     * @notice Withdrawals are allowed an the asset out is WETH
     * Copied the original ERC4626 code back to override `PufferVault` + wrap ETH logic
     */
    function withdraw(uint256 assets, address receiver, address owner) public virtual override returns (uint256) {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        _checkDailyWithdrawalLimits(assets); //@todo figure if it is better to override `maxWithdraw`

        _wrapETH(assets);

        uint256 shares = previewWithdraw(assets);
        // solhint-disable-next-line func-named-parameters
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    /**
     * @notice Withdrawals are allowed an the asset out is WETH
     * Copied the original ERC4626 code back to override `PufferVault` + wrap ETH logic
     */
    function redeem(uint256 shares, address receiver, address owner) public virtual override returns (uint256) {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        uint256 assets = previewRedeem(shares);

        _checkDailyWithdrawalLimits(assets); //@todo figure if it is better to override `maxWithdraw`

        _wrapETH(assets);

        // solhint-disable-next-line func-named-parameters
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    /**
     * @param withdrawalAmount is the assets amount, not shares
     */
    function _checkDailyWithdrawalLimits(uint256 withdrawalAmount) internal {
        VaultStorage storage $ = _getPufferVaultStorage();
        // Check if it's a new day to reset the withdrawal count
        if ($.lastWithdrawalDay < block.timestamp / 1 days) {
            $.lastWithdrawalDay = uint64(block.timestamp / 1 days);
            $.withdrawnToday = 0;
        }

        if ($.withdrawnToday + withdrawalAmount > $.dailyWithdrawalLimit) {
            revert ExceededDailyWithdrawalLimit($.dailyWithdrawalLimit, $.withdrawnToday, withdrawalAmount);
        }

        $.withdrawnToday += uint96(withdrawalAmount);
    }

    /**
     * @notice Deposits native ETH
     */
    function depositETH(address receiver) public payable virtual returns (uint256) {
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
     * @notice Transfers ETH to a specified address
     * @dev Restricted to PufferProtocol
     * We use it to transfer ETH to PufferModule
     * copied from https://github.com/Vectorized/solady/blob/fb11b3e9ea6c1aafdbd0a1515ff440509d60bff9/src/utils/SafeTransferLib.sol#L64
     * @param to The address to transfer ETH to
     * @param ethAmount The amount of ETH to transfer
     */
    function transferETH(address to, uint256 ethAmount) external restricted {
        // Our Vault will hold ETH & WETH
        // If we don't have enough ETH for the transfer, unwrap WETH
        uint256 ethBalance = address(this).balance;
        if (ethBalance < ethAmount) {
            _WETH.withdraw(ethAmount - ethBalance);
        }

        /// @solidity memory-safe-assembly
        assembly {
            if iszero(call(gas(), to, ethAmount, codesize(), 0x00, codesize(), 0x00)) {
                mstore(0x00, 0xb12d13eb) // `ETHTransferFailed()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /**
     * @notice Allows the `msg.sender` to burn his shares
     * @param shares The amount of shares to burn
     */
    function burn(uint256 shares) public {
        _burn(msg.sender, shares);
    }

    /**
     * @notice Sets a new daily withdrawal limit
     * @dev Restricted to DAO
     * @param newLimit The new daily limit to be set
     */
    function setDailyLimit(uint96 newLimit) external restricted {
        VaultStorage storage $ = _getPufferVaultStorage();
        emit DailyWithdrawalLimitSet($.dailyWithdrawalLimit, newLimit);
        $.dailyWithdrawalLimit = newLimit;
    }

    function _wrapETH(uint256 assets) internal {
        uint256 wethBalance = _WETH.balanceOf(address(this));

        if (wethBalance < assets) {
            _WETH.deposit{ value: assets - wethBalance }();
        }
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
