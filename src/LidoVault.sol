// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { IStETH } from "src/interface/IStETH.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC721Receiver } from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { IEigenLayer, IStrategy } from "src/interface/IEigenLayer.sol";

interface ILidoWithdrawalQueue {
    function requestWithdrawals(uint256[] calldata _amounts, address _owner)
        external
        returns (uint256[] memory requestIds);

    function findCheckpointHints(uint256[] calldata _requestIds, uint256 _firstIndex, uint256 _lastIndex)
        external
        view
        returns (uint256[] memory hintIds);

    function claimWithdrawals(uint256[] memory _requestIds, uint256[] memory _hints) external;

    function getLastCheckpointIndex() external view returns (uint256);

    function claimWithdrawal(uint256 _requestId) external;
}

contract LidoVault is IERC721Receiver {
    using SafeERC20 for address;

    event RequestedWithdrawals(uint256[]);

    IStrategy internal constant _EIGEN_STETH_STRATEGY = IStrategy(0x93c4b944D05dfe6df7645A86cd2206016c51564D);
    IEigenLayer internal constant _EIGEN_STRATEGY_MANAGER = IEigenLayer(0x858646372CC42E1A627fcE94aa7A7033e7CF075A);
    IStETH internal constant _ST_ETH = IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    ILidoWithdrawalQueue internal constant _LIDO_WITHDRAWAL_QUEUE =
        ILidoWithdrawalQueue(0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1);
    address internal constant _W_STETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    constructor() {
        // Approve stETH to Lido && EL
        SafeERC20.safeIncreaseAllowance(_ST_ETH, address(_LIDO_WITHDRAWAL_QUEUE), type(uint256).max);
        SafeERC20.safeIncreaseAllowance(_ST_ETH, address(_EIGEN_STRATEGY_MANAGER), type(uint256).max);
    }

    receive() external payable { }

    function depositStETH() external { }

    /**
     * @notice Returns the total ETH amount locked in EigenLayer and this Vault
     */
    function getTotalBackingEthAmount() public view returns (uint256) {
        uint256 vaultAmount = getBackingEthAmount();
        uint256 elAmount = getELBackingEthAmount();
        return vaultAmount + elAmount;
    }

    /**
     * @notice Returns the ETH amount that is backing this vault
     */
    function getBackingEthAmount() public view returns (uint256 ethAmount) {
        uint256 shares = _ST_ETH.sharesOf(address(this));
        ethAmount = _ST_ETH.getPooledEthByShares(shares);
    }

    /**
     * @notice Returns the ETH amount that is backing this vault locked in EigenLayer stETH strategy
     */
    function getELBackingEthAmount() public view returns (uint256 ethAmount) {
        (IStrategy[] memory strategies, uint256[] memory amounts) = _EIGEN_STRATEGY_MANAGER.getDeposits(address(this));
        for (uint256 i = 0; i < strategies.length; ++i) {
            if (address(strategies[i]) == address(_EIGEN_STETH_STRATEGY)) {
                return amounts[i];
            }
        }
        return 0;
    }

    /**
     * @notice Initiates ETH withdrawals from Lido
     * @param amounts An array of amounts that we want to queue
     */
    function initiateETHWithdrawals(uint256[] calldata amounts) external returns (uint256[] memory requestIds) {
        requestIds = _LIDO_WITHDRAWAL_QUEUE.requestWithdrawals(amounts, address(this));
        emit RequestedWithdrawals(requestIds);
        return requestIds;
    }

    /**
     * @notice Claims ETH withdrawals from Lido
     * @param requestIds An array of request IDs for the withdrawals
     */
    function claimWithdrawals(uint256[] calldata requestIds) external {
        for (uint256 i = 0; i < requestIds.length; ++i) {
            _LIDO_WITHDRAWAL_QUEUE.claimWithdrawal(requestIds[i]);
        }
    }

    function transferEth() external {
        // send eth to pool without minting new pufETH
    }

    /**
     * @notice Required by the ERC721 Standard
     */
    function onERC721Received(address, address, uint256, bytes calldata) external virtual returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
