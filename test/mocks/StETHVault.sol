// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;

import { IStETHVault } from "../../src/interface/IStETHVault.sol";
import { IStETH } from "../../src/interface/IStETH.sol";
import { IEigenLayer, IStrategy, QueuedWithdrawal, WithdrawerAndNonce } from "../../src/interface/IEigenLayer.sol";

import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";

contract StETHVault is IStETHVault {
    uint256 MAX_APPROVAL = ~uint256(0);
    // StrategyManager contract address
    IEigenLayer public constant EIGENLAYER = IEigenLayer(0xdAC17F958D2ee523a2206206994597C13D831ec7); // todo

    IStETH public constant stETH = IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    IStrategy public constant stETHStrategy = IStrategy(address(0x0)); // todo

    constructor() public {
        stETH.approve(address(EIGENLAYER), MAX_APPROVAL);
    }

    function depositToEigenLayer(uint256 amount) external returns (uint256) {
        // Deposit stETH into EigenLayer using the specified strategy
        return EIGENLAYER.depositIntoStrategy(stETHStrategy, IERC20(address(stETH)), amount);
    }

    function queueWithdrawalFromEigenLayer(uint256 shares) external returns (bytes32) {
        // Queue a withdrawal from EigenLayer
        uint256[] memory strategyIndexes = new uint256[](1);
        IStrategy[] memory strategies = new IStrategy[](1);
        uint256[] memory sharesArray = new uint256[](1);

        strategyIndexes[0] = 0; // Index of stETHStrategy todo
        strategies[0] = stETHStrategy;
        sharesArray[0] = shares;

        return EIGENLAYER.queueWithdrawal(strategyIndexes, strategies, sharesArray, address(this), false);
    }

    function completeWithdrawalFromEigenLayer(uint256 shares) external {
        // Complete a queued withdrawal from EigenLayer
        IStrategy[] memory strategies = new IStrategy[](1);
        IERC20[] memory tokens = new IERC20[](1);
        uint256 middlewareTimesIndex = 0; // todo
        uint256[] memory sharesArray = new uint256[](1);

        strategies[0] = stETHStrategy;
        tokens[0] = IERC20(address(stETH));
        sharesArray[0] = shares;

        EIGENLAYER.completeQueuedWithdrawal(
            QueuedWithdrawal(
                strategies,
                sharesArray,
                address(this),
                WithdrawerAndNonce(address(this), 0), //todo
                0, // todo
                address(0) // todo
            ),
            tokens,
            middlewareTimesIndex,
            false
        );
    }

    // Trigger redemptions from Lido
    // function queueWithdrawalFromLido() external;

    // function completeWithdrawalFromLido() external;
}
