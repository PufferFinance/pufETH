// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;
import {IEigenLayer, IStrategy, QueuedWithdrawal, WithdrawerAndNonce} from "../../src/interface/IEigenLayer.sol";
import {IStETH} from "../../src/interface/IStETH.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

contract EigenLayer is IEigenLayer {
    IStETH public constant stETH =
        IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    // https://github.com/Layr-Labs/eigenlayer-contracts/blob/0139d6213927c0a7812578899ddd3dda58051928/src/contracts/core/StrategyManager.sol#L221
    function depositIntoStrategy(
        IStrategy strategy,
        IERC20 token,
        uint256 amount
    ) external returns (uint256 shares) {
        stETH.transferFrom(msg.sender, address(this), amount);
        return amount;
    }

    function queueWithdrawal(
        uint256[] calldata strategyIndexes,
        IStrategy[] calldata strategies,
        uint256[] calldata shares,
        address withdrawer,
        bool undelegateIfPossible
    ) external returns (bytes32) {}

    function completeQueuedWithdrawal(
        QueuedWithdrawal calldata queuedWithdrawal,
        IERC20[] calldata tokens,
        uint256 middlewareTimesIndex,
        bool receiveAsTokens
    ) external {
        stETH.transfer(msg.sender, queuedWithdrawal.shares[0]);
    }
}
