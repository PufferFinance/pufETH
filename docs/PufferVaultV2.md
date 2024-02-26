# PufferVault


| File | Type | Upgradeable | Inherited | Deployed |
| -------- | -------- | -------- | -------- | -------- |
| [`IPufferVault.sol`](../src/interface/IPufferVault.sol) | Singleton | / | YES | / |
| [`PufferVault.sol`](../src/PufferVault.sol) | Singleton | UUPS Proxy | YES | [0xd9a4...a72](https://etherscan.io/address/0xd9a442856c234a39a81a089c06451ebaa4306a72) |
| [`PufferVaultV2.sol`](../src/PufferVaultV2.sol) | Singleton | UUPS Proxy | NO | / |
| [`PufferVaultStorage.sol`](../src/PufferVaultStorage.sol) | Singleton | UUPS Proxy | YES | / |

The PufferVault is in charge of custodying funds for the Puffer protocol. The [initial V1 deployment](https://etherscan.io/address/0xd9a442856c234a39a81a089c06451ebaa4306a72) is an ERC4626 vault with stETH as the underlying asset. The PufferVaultV2 contract is the next upgrade, which changes the underlying asset to wETH and adds functionality to support the Puffer protocol's mainnet deployment.

#### High-level Concepts

This document organizes methods according to the following themes (click each to be taken to the relevant section):
* [Inherited from PufferVault](#inherited-from-puffervault)
* [Depositing](#depositing)
* [Withdrawing](#withdrawing)
* [Redeeming](#redeeming)
* [Transferring](#transferring)
* [Burning](#burning)
* [Setter Methods](#setter-methods)
* [Getter Methods](#getter-methods)

#### Important state variables

The PufferVault maintains the addresses of important contracts related to EigenLayer and Lido. The PufferVaultV2 accesses PufferVaultStorage, where other important information is maintained. Important state variables are described below:

#### PufferVault

* `IStrategy internal immutable _EIGEN_STETH_STRATEGY`: The EigenLayer strategy for depositing stETH
* `IEigenLayer internal immutable _EIGEN_STRATEGY_MANAGER`: EigenLayer's StrategyManager contract, responsible for handling deposits and withdrawals related to EigenLayer's strategy contracts, such as the EigenLayer stETH strategy contract
* `IStETH internal immutable _ST_ETH`: Lido's stETH address
* `ILidoWithdrawalQueue internal immutable _LIDO_WITHDRAWAL_QUEUE`: Lido's contract responsible for handling withdrawals of stETH into ETH

#### PufferVaultStorage

* `uint256 lidoLockedETH`: The amount of ETH the Puffer Protocol has locked inside of Lido
* `uint256 eigenLayerPendingWithdrawalSharesAmount`: The amount of stETH shares the Puffer vault has pending for withdrawal from EigenLayer
* `bool isLidoWithdrawal`: Deprecated from PufferVault version 1
* `EnumerableSet.UintSet lidoWithdrawals`: Deprecated from PufferVault version 1
* `EnumerableSet.Bytes32Set eigenLayerWithdrawals`: Tracks withdrawalRoots from EigenLayer withdrawals
* `EnumerableMap.UintToUintMap lidoWithdrawalAmounts`: Tracks the amounts of corresponding to each Lido withdrawal
* `uint96 dailyAssetsWithdrawalLimit`: The maximum assets (wETH) that can be withdrawn from the vault per day
* `uint96 assetsWithdrawnToday`: The amount of assets (wETH) that has been withdrawn today
* `uint64 lastWithdrawalDay`: Tracks when the day ends to reset `assetsWithdrawnToday`
* `uint256 exitFeeBasisPoints`: Penalty when withdrawing to mitigate oracle sandwich attacks  

#### PufferVaultV2
* `IWETH internal immutable _WETH`: Address of wrapped ETH contract (wETH)
* `IPufferOracle public immutable PUFFER_ORACLE`: The address of the Puffer Oracle responsible for submitting proof-of-reserves.

---


### Inherited from PufferVault
- [`depositToEigenLayer`](./PufferVault.md#depositToEigenLayer)
- [`initiateStETHWithdrawalFromEigenLayer`](./PufferVault.md#initiateStETHWithdrawalFromEigenLayer)
- [`claimWithdrawalFromEigenLayer`](./PufferVault.md#claimWithdrawalFromEigenLayer)


### Depositing

#### `depositETH`

```solidity
function depositETH(address receiver) 
    public 
    payable 
    virtual 
    restricted 
    returns (uint256)
```

This function is used to deposit native ETH into the Puffer Vault.

The function is restricted, meaning it can only be executed when the contract is not paused. This is similar to the whenNotPaused modifier from the Pausable.sol contract.

The function takes one parameter:

> `receiver`: This is the address of the recipient who will receive the pufETH tokens.

The function returns one value:

> `shares`: This is the amount of pufETH tokens that the receiver gets from the deposit.

#### `depositStETH`

```solidity
function depositStETH(uint256 assets, address receiver) 
    public 
    virtual 
    restricted 
    returns (uint256) 
```

This function is used to deposit stETH into the Puffer Vault.

Similar to the previous function, it is restricted and can only be executed when the contract is not paused. This is akin to the whenNotPaused modifier from the Pausable.sol contract.

The function takes two parameters:

> `assets`: This is the amount of stETH that is to be deposited into the vault.

> `receiver`: This is the address of the recipient who will receive the pufETH tokens.

The function returns one value:

> `shares`: This is the amount of pufETH tokens that the receiver gets from the deposit.

### Withdrawing

#### `initiateETHWithdrawalsFromLido`

```solidity
function initiateETHWithdrawalsFromLido(uint256[] calldata amounts)
    external
    virtual
    override
    restricted
    returns (uint256[] memory requestIds)
```

This function is used to initiate withdrawals of ETH from Lido (was overloaded from PufferVault version 1).

The function is restricted to the Operations Multisig, meaning only the operations multi-sig wallet can execute this function.

The function takes one parameter:

> `amounts`: This is an array of stETH amounts that are to be queued for withdrawal.

The function returns one value:

> `requestIds`: This is an array of request IDs corresponding to the withdrawals. Each withdrawal request has a unique ID for tracking and reference purposes.

#### `claimWithdrawalsFromLido`

```solidity
function claimWithdrawalsFromLido(uint256[] calldata requestIds) 
    external 
    virtual 
    override 
    restricted
```

This function is used to claim ETH withdrawals from Lido (was overloaded from PufferVault version 1).

The function is restricted to the Operations Multisig, meaning only the operations multi-signature wallet can execute this function.

The function takes one parameter:

> `requestIds`: This is an array of request IDs corresponding to the withdrawals that are to be claimed. Each withdrawal request has a unique ID for tracking and reference purposes.

#### `withdraw`

```solidity
function withdraw(uint256 assets, address receiver, address owner)
    public
    virtual
    override
    restricted
    returns (uint256)
```

This function is used to withdraw wETH assets from the vault. In the process, the pufETH shares of the owner are burned.

The caller of this function does not have to be the owner if the owner has approved the caller to spend their pufETH.

The function is restricted, meaning it can only be executed when the contract is not paused. This is similar to the whenNotPaused modifier from the Pausable.sol contract.

The function takes three parameters:

> `assets`: This is the amount of wETH assets that are to be withdrawn.

> `receiver`: This is the address that will receive the WETH assets.

> `owner`: This is the address of the owner whose pufETH shares are to be burned.

The function returns one value:

> `shares`: This is the amount of pufETH shares that are burned in the process.

---

### Redeeming

#### `redeem`

```solidity
function redeem(uint256 shares, address receiver, address owner)
    public
    virtual
    override
    restricted
    returns (uint256)
```

This function is used to redeem pufETH shares in exchange for wETH assets from the vault. In the process, the pufETH shares of the owner are burned.

The caller of this function does not have to be the owner if the owner has approved the caller to spend their pufETH.

The function is restricted, meaning it can only be executed when the contract is not paused. This is similar to the whenNotPaused modifier from the Pausable.sol contract.

The function takes three parameters:

> `shares`: This is the amount of pufETH shares that are to be withdrawn.

> `receiver`: This is the address that will receive the wETH assets.

> `owner`: This is the address of the owner whose pufETH shares are to be burned.

The function returns one value:

> `assets`: This is the amount of wETH assets that are redeemed.

---


### Transferring

#### `transferETH`

```solidity
function transferETH(address to, uint256 ethAmount) 
    external 
    restricted
```

This function is used to transfer ETH from the vault to a specified address.

The function is restricted to the PufferProtocol contract, meaning only this contract can execute the function.

The function is used to transfer ETH to PufferModules in order to fund Puffer validators.

The function takes two parameters:

> `to`: This is the address of the PufferModule where the ETH will be transferred to.

> `ethAmount`: This is the amount of ETH that is to be transferred.

---

### Burning

#### `burn`

```solidity
function burn(uint256 shares) 
    public 
    restricted
```

This function allows the msg.sender (the one who initiates the transaction) to burn their pufETH shares.

The function is restricted, meaning it can only be executed when the contract is not paused. This is similar to the whenNotPaused modifier from the Pausable.sol contract.

The function is primarily used to burn portions of Puffer validator bonds due to inactivity or slashing.

The function takes one parameter:

> `shares`: This is the amount of pufETH shares that are to be burned.

---

### Setter Methods

#### `setDailyWithdrawalLimit`

```solidity
function setDailyWithdrawalLimit(uint96 newLimit) 
    external 
    restricted 
```

This function is used to set a new daily withdrawal limit (restricted to the DAO).

The function takes one parameter:

> `newLimit`: This is the new daily limit that is to be set for withdrawals.

---


### Getter Methods

#### `totalAssets`

```solidity
function totalAssets() 
    public 
    view 
    virtual 
    override 
    returns (uint256)
```

This function is used to calculate the total assets backing the pufETH nLRT.

The pufETH shares of the vault are primarily backed by the wETH asset. However, at any point in time, the full backing may be a combination of stETH, WETH, and ETH.

The `totalAssets()` function calculates the total assets by summing the following:

- wETH held in the vault contract
- ETH held in the vault contract
- The oracle-reported Puffer validator ETH locked in the Beacon chain 
- stETH held in the vault contract, in EigenLayer's stETH strategy, and in Lido's withdrawal queue. (It is assumed that stETH is always 1:1 with ETH since it's rebasing)

The function does not take any parameters and returns one value:

> The total assets of the vault. This is a numerical value represented as a uint256.

#### `maxWithdraw`

```solidity
function maxWithdraw(address owner) 
    public 
    view 
    virtual 
    override 
    returns (uint256 maxAssets) 
```

This function is used to calculate the maximum amount of wETH assets that can be withdrawn by the owner.

The function considers both the remaining daily withdrawal limit and the owner's balance.

The function takes one parameter:

> `owner`: This is the address of the owner for whom the maximum withdrawal amount is calculated.

The function returns one value:

> `maxAssets`: This is the maximum amount of WETH assets that can be withdrawn by the owner.

#### `maxRedeem`

```solidity
function maxRedeem(address owner)
    public 
    view 
    virtual 
    override 
    returns (uint256 maxShares)
```

This function is used to calculate the maximum amount of pufETH shares that can be redeemed by the owner.

The function considers both the remaining daily withdrawal limit in terms of assets and converts it to shares, and the owner's share balance.

The function takes one parameter:

> `owner`: This is the address of the owner for whom the maximum redeemable shares are calculated.

The function returns one value:

> `maxShares`: This is the maximum amount of pufETH shares that can be redeemed by the owner.

#### `getRemainingAssetsDailyWithdrawalLimit`

```solidity
function getRemainingAssetsDailyWithdrawalLimit() 
    public 
    view 
    virtual 
    returns (uint96) 
```

This function is used to get the remaining assets that can be withdrawn for the current day.

The function does not take any parameters.

The function returns one value:

> The remaining assets (wETH) that can be withdrawn today. This is a numerical value represented as a uint96.