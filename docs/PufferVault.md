# PufferVault

| File | Type | Upgradeable | Inherited | Deployed |
| -------- | -------- | -------- | -------- | -------- |
| [`IPufferVault.sol`](../src/interface/IPufferVault.sol) | Singleton | / | YES | / |
| [`PufferVault.sol`](../src/PufferVault.sol) | Singleton | UUPS Proxy | YES | / |
| [`PufferVaultV2.sol`](../src/PufferVaultV2.sol) | Singleton | UUPS Proxy | NO | / |
| [`PufferVaultStorage.sol`](../src/PufferVaultStorage.sol) | Singleton | UUPS Proxy | YES | / |

The Puffer Vault is in charge of custodying funds for the protocol. Initially it will facilitate depositing stETH into EigenLayer to farm points. Then it will facilitate both withdrawing stETH from EigenLayer and subsequently withdrawing stETH from Lido to redeem ETH. 

#### High-level Concepts

This document organizes methods according to the following themes (click each to be taken to the relevant section):
* [Depositing](#depositing)
* [Withdrawing](#withdrawing)
* [Getter Methods](#getter-methods)

#### Important state variables

The PufferVault maintains the addresses of important contracts related to EigenLayer and Lido. The PufferVaultV2 accesses PufferVaultStorage, where other important information is maintained. Important state variables are described below:

#### PufferVault

* `IStrategy internal immutable _EIGEN_STETH_STRATEGY`: The EigenLayer strategy for depositing stETH and farming points
* `IEigenLayer internal immutable _EIGEN_STRATEGY_MANAGER`: EigenLayer's StrategyManager contract, responsible for handling deposits and withdrawals related to EigenLayer's strategy contracts, such as the EigenLayer stETH strategy contract
* `ILidoWithdrawalQueue internal immutable _LIDO_WITHDRAWAL_QUEUE`: Lido's contract responsible for handling withdrawals of stETH into ETH

#### PufferVaultStorage

* `uint256 lidoLockedETH`: The amount of ETH the Puffer Protocol has locked inside of Lido
* `uint256 eigenLayerPendingWithdrawalSharesAmount`: The amount of shares Puffer Protocol has pending for withdrawal from EigenLayer

---

### Depositing

#### `depositToEigenLayer`

```solidity
function depositToEigenLayer(uint256 amount) external virtual restricted
```

This function allows the vault to deposit stETH into EigenLayer's stETH strategy contract in order to farm points

*Effects*
* Moves stETH from the vault contract to EigenLayer's stETH strategy contract
* Increases the number of shares the vault contract has corresponding to EigenLayer's stETH strategy

*Requirements*
* Only callable by the operations or community multisigs

---

### Withdrawing

#### `initiateStETHWithdrawalFromEigenLayer`

```solidity
function initiateStETHWithdrawalFromEigenLayer(uint256 sharesToWithdraw) external virtual restricted
```

Initiates the withdrawal process of stETH from EigenLayer's stETH strategy contract

*Effects*
* Queues a withdrawal from EigenLayer's stETH strategy contract, which can later be redeemed by a separate function call

*Requirements*
* Only callable by the operations or community multisigs

#### `claimWithdrawalFromEigenLayer`

```solidity
function claimWithdrawalFromEigenLayer(
    IEigenLayer.QueuedWithdrawal calldata queuedWithdrawal,
    IERC20[] calldata tokens,
    uint256 middlewareTimesIndex
) external virtual
```

Completes the process of withdrawing stETH from EigenLayer's stETH strategy contract

*Effects*
* Claims the previously queued withdrawal from EigenLayer's stETH strategy contract
* Transfers stETH from EigenLayer's stETH strategy contract to this vault contract

*Requirements*
* There must be a corresponding queued withdrawal created previously via function `initiateStETHWithdrawalFromEigenLayer`
* Enough time must have elapsed since creation of the queued withdrawal such that it is claimable at the time of this function call

#### `initiateETHWithdrawalsFromLido`

```solidity
function initiateETHWithdrawalsFromLido(uint256[] calldata amounts)
    external
    virtual
    restricted
    returns (uint256[] memory requestIds)
```

Begins the process of redeeming stETH for ETH from the Lido protocol

*Effects*
* Queues a pending withdrawal of stETH for ETH on Lido

*Requirements*
* Only callable by the operations or community multisigs


#### `claimWithdrawalsFromLido`

```solidity
function claimWithdrawalsFromLido(uint256[] calldata requestIds) external virtual
```

This function claims withdrawals that were previously queued. This completes the two-step process of withdrawing stETH for ETH on Lido.

*Effects*:
* Sends the vault contract ETH from Lido
* Marks the pending withdrawal claim as claimed

*Requirements*:
* There must be a corresponding pending claim that is ready to be claimed from Lido. In other words, the withdrawal must have been previously queued, and that withdrawal claim must be ready for redemption

---

### Getter Methods

#### `totalAssets`

```solidity
function totalAssets() public view virtual override returns (uint256)
```

This function returns the total amount of assets on the vault, denominated in ETH. This includes any ETH balances directly on the contract, stETH balances (since stETH is 1:1 with ETH), and locked ETH or stETH within EigenLayer or Lido
