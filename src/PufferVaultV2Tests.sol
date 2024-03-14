// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { PufferVaultV2 } from "./PufferVaultV2.sol";
import { IStETH } from "./interface/Lido/IStETH.sol";
import { ILidoWithdrawalQueue } from "./interface/Lido/ILidoWithdrawalQueue.sol";
import { IEigenLayer } from "./interface/EigenLayer/IEigenLayer.sol";
import { IStrategy } from "./interface/EigenLayer/IStrategy.sol";
import { IWETH } from "./interface/Other/IWETH.sol";
import { IPufferOracle } from "./interface/IPufferOracle.sol";

contract PufferVaultV2Tests is PufferVaultV2 {
    constructor(
        IStETH stETH,
        IWETH weth,
        ILidoWithdrawalQueue lidoWithdrawalQueue,
        IStrategy stETHStrategy,
        IEigenLayer eigenStrategyManager,
        IPufferOracle oracle
    ) PufferVaultV2(stETH, weth, lidoWithdrawalQueue, stETHStrategy, eigenStrategyManager, oracle) {
        _WETH = weth;
        PUFFER_ORACLE = oracle;
        _disableInitializers();
    }

    // This functionality must be disabled because of the foundry tests
    function _markDeposit() internal virtual override { }
}
