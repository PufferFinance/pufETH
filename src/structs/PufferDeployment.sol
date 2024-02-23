// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

struct PufferDeployment {
    address accessManager;
    address pufferDepositorImplementation;
    address pufferDepositor;
    address pufferVault;
    address pufferVaultImplementation;
    address pufferOracle;
    address stETH;
    address weth;
    address timelock;
    address lidoWithdrawalQueueMock;
    address stETHStrategyMock;
    address eigenStrategyManagerMock;
}
