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
    // slither-disable-next-line unused-state
    IWETH internal constant _WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    constructor(
        IStETH stETH,
        ILidoWithdrawalQueue lidoWithdrawalQueue,
        IStrategy stETHStrategy,
        IEigenLayer eigenStrategyManager
    ) PufferVault(stETH, lidoWithdrawalQueue, stETHStrategy, eigenStrategyManager) {
        _ST_ETH = stETH;
        _LIDO_WITHDRAWAL_QUEUE = lidoWithdrawalQueue;
        _EIGEN_STETH_STRATEGY = stETHStrategy;
        _EIGEN_STRATEGY_MANAGER = eigenStrategyManager;
        // Approve stETH to Lido && EL
        _disableInitializers();
    }

    /**
     * @notice Changes token from stETH to WETH
     */
    function initialize() public reinitializer(2) {
        ERC4626Storage storage $ = _getERC4626StorageInternal();
        $._asset = _WETH;
    }

    /**
     * @dev See {IERC4626-totalAssets}.
     * Eventually, stETH will not exist anymore, and the Vault will represent shares of total ETH holdings
     * ETH to stETH is always 1:1 (stETH is rebasing token)
     * Sum of EL assets + Vault Assets
     */
    function totalAssets() public view virtual override returns (uint256) {
        return _ST_ETH.balanceOf(address(this)) + getELBackingEthAmount() + _WETH.balanceOf(address(this))
            + address(this).balance; //@todo when you add oracle pufferOracle.getLockedEthAmount()
    }

    //@todo weth wrapping and unwrapping logic, native ETH deposit method

    /**
     * @notice Withdrawals are allowed an the asset out is WETH
     * Copied the original ERC4626 code back to override `PufferVault`
     */
    function withdraw(uint256 assets, address receiver, address owner) public virtual override returns (uint256) {
        uint256 maxAssets = maxWithdraw(owner);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, assets, maxAssets);
        }

        uint256 shares = previewWithdraw(assets);
        // solhint-disable-next-line func-named-parameters
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return shares;
    }

    /**
     * @notice Withdrawals are allowed an the asset out is WETH
     * Copied the original ERC4626 code back to override `PufferVault`
     */
    function redeem(uint256 shares, address receiver, address owner) public virtual override returns (uint256) {
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        uint256 assets = previewRedeem(shares);
        // solhint-disable-next-line func-named-parameters
        _withdraw(_msgSender(), receiver, owner, assets, shares);

        return assets;
    }

    // slither-disable-next-line dead-code
    function _wrap(uint256 amount) internal {
        _WETH.deposit{ value: amount }();
    }

    // slither-disable-next-line dead-code
    function _unwrap(uint256 amount) internal {
        _WETH.withdraw(amount);
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
