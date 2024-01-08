// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { IStETH } from "src/interface/IStETH.sol";
import { ILidoWithdrawalQueue } from "src/interface/ILidoWithdrawalQueue.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IEigenLayer, IStrategy } from "src/interface/IEigenLayer.sol";
import { UUPSUpgradeable } from "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessManagedUpgradeable } from
    "@openzeppelin-contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";
import {
    ERC4626Upgradeable,
    ERC20Upgradeable
} from "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import { ERC4626Upgradeable } from "@openzeppelin-contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

/**
 * @title PufferVault
 * @author Puffer Finance
 * @custom:security-contact security@puffer.fi
 */
contract PufferVault is IERC721Receiver, AccessManagedUpgradeable, ERC4626Upgradeable, UUPSUpgradeable {
    //@todo check what to override on ERC4626Upgradeable
    //@todo should probably add `restricted` to some of the external/public functions so that we can pause/unpause in state of an emergency
    using SafeERC20 for address;

    /**
     * @notice Emitted when we request withdrawals from Lido
     */
    event RequestedWithdrawals(uint256[]);

    IStrategy internal constant _EIGEN_STETH_STRATEGY = IStrategy(0x93c4b944D05dfe6df7645A86cd2206016c51564D);
    IEigenLayer internal constant _EIGEN_STRATEGY_MANAGER = IEigenLayer(0x858646372CC42E1A627fcE94aa7A7033e7CF075A);
    IStETH internal constant _ST_ETH = IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    ILidoWithdrawalQueue internal constant _LIDO_WITHDRAWAL_QUEUE =
        ILidoWithdrawalQueue(0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1);

    //@todo Should support depositing of wstETH
    // slither-disable-next-line unused-state
    address internal constant _W_STETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    constructor() {
        // Approve stETH to Lido && EL
        _disableInitializers();
    }

    function initialize(address accessManager) external initializer {
        __AccessManaged_init(accessManager);
        __ERC4626_init(_ST_ETH);
        __ERC20_init("pufETH", "pufETH");
        SafeERC20.safeIncreaseAllowance(_ST_ETH, address(_LIDO_WITHDRAWAL_QUEUE), type(uint256).max);
        SafeERC20.safeIncreaseAllowance(_ST_ETH, address(_EIGEN_STRATEGY_MANAGER), type(uint256).max);
    }

    receive() external payable virtual { }

    /**
     * @notice Not allowed
     */
    function redeem(uint256, address, address) public virtual override returns (uint256) {
        //@todo figure out
        revert("Not allowed");
    }

    /**
     * @notice Not allowed
     */
    function withdraw(uint256, address, address) public virtual override returns (uint256) {
        //@todo figure out
        revert("Not allowed");
    }

    /**
     * notice Deposits stETH into `stETH` EigenLayer strategy
     * @param amount the amount of stETH to deposit
     */
    function depositToEigenLayer(uint256 amount) external virtual restricted {
        _EIGEN_STRATEGY_MANAGER.depositIntoStrategy({ strategy: _EIGEN_STETH_STRATEGY, token: _ST_ETH, amount: amount });
    }

    /**
     * @dev See {IERC4626-totalAssets}.
     * Eventually, stETH will not exist anymore, and the Vault will represent shares of total ETH holdings
     * ETH to stETH is always 1:1 (stETH is rebasing token)
     * Sum of EL assets + Vault Assets
     */
    function totalAssets() public view virtual override returns (uint256) {
        return _ST_ETH.balanceOf(address(this)) + getELBackingEthAmount() + address(this).balance;
    }

    /**
     * @notice Returns the ETH amount that is backing this vault locked in EigenLayer stETH strategy
     */
    function getELBackingEthAmount() public view virtual returns (uint256 ethAmount) {
        //@todo optimize, no loop, look on the strategy directly or something
        uint256 elShares;
        // EigenLayer returns the number of shares owned in that strategy
        (IStrategy[] memory strategies, uint256[] memory amounts) = _EIGEN_STRATEGY_MANAGER.getDeposits(address(this));
        for (uint256 i = 0; i < strategies.length; ++i) {
            if (address(strategies[i]) == address(_EIGEN_STETH_STRATEGY)) {
                elShares = amounts[i];
                break;
            }
        }

        // No deposits to EL
        if (elShares == 0) {
            return 0;
        }

        // ETH is 1:1 with stETH
        // EL Keeps track of deposits in their own shares
        // This is how we get the stETHAmount owned in EL
        ethAmount = (elShares * _ST_ETH.balanceOf(address(_EIGEN_STETH_STRATEGY))) / _EIGEN_STETH_STRATEGY.totalShares();
    }

    /**
     * @notice Initiates ETH withdrawals from Lido
     * @param amounts An array of amounts that we want to queue
     */
    function initiateETHWithdrawalsFromLido(uint256[] calldata amounts)
        external
        virtual
        restricted
        returns (uint256[] memory requestIds)
    {
        requestIds = _LIDO_WITHDRAWAL_QUEUE.requestWithdrawals(amounts, address(this));
        emit RequestedWithdrawals(requestIds);
        return requestIds;
    }

    /**
     * @notice Claims ETH withdrawals from Lido
     * @param requestIds An array of request IDs for the withdrawals
     */
    function claimWithdrawalsFromLido(uint256[] calldata requestIds) external virtual {
        //@todo can probably be optimized
        for (uint256 i = 0; i < requestIds.length; ++i) {
            // slither-disable-next-line calls-loop
            _LIDO_WITHDRAWAL_QUEUE.claimWithdrawal(requestIds[i]);
        }
    }

    /**
     * @notice Required by the ERC721 Standard
     */
    function onERC721Received(address, address, uint256, bytes calldata) external virtual returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // slither-disable-next-line dead-code
    function _authorizeUpgrade(address newImplementation) internal virtual override restricted { }
}
