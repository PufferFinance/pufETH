# PufferDepositor

### [PufferDepositorV2](./PufferDepositorV2.md)

| File | Type | Upgradeable | Inherited | Deployed |
| -------- | -------- | -------- | -------- | -------- |
| [`IPufferDepositorV2.sol`](../src/interface/IPufferDepositorV2.sol) | Singleton | / | YES | / |
| [`PufferDepositorV2.sol`](../src/PufferDepositorV2.sol) | Singleton | UUPS Proxy | NO | / |
| [`PufferDepositorStorage.sol`](../src/PufferDepositorStorage.sol) | Singleton | UUPS Proxy | YES | / |

The PufferDepositorV2 facilitates depositing stETH and wstETH into the [PufferVaultV2](./PufferVaultV2.md).

#### Important state variables

The only state information the PufferDepositor contract holds are the addresses of stETH (`_ST_ETH`) and wstETH (`_WST_ETH`).

---

### Functions

#### `depositStETH`

```solidity
    function depositStETH(Permit calldata permitData, address recipient)
        external
        restricted
        returns (uint256 pufETHAmount)
```

Interface function to deposit stETH into the `PufferVault` contract, which mints pufETH for the `recipient`.  

*Effects*
* Takes the specified amount of stETH from the caller
* Deposits the stETH into the `PufferVault` contract
* Mints pufETH for the `recipient`, corresponding to the stETH amount deposited

*Requirements*
* Called must have previously approved the amount of stETH to be sent to the `PufferDepositor` contract

#### `depositWstETH`

```solidity
    function depositWstETH(Permit calldata permitData, address recipient)
        external
        restricted
        returns (uint256 pufETHAmount)
```

Interface function to deposit wstETH into the `PufferVault` contract, which mints pufETH for the `recipient`.  

*Effects*
* Takes the specified amount of wstETH from the caller
* Unwraps the wstETH into stETH
* Deposits the stETH into the `PufferVault` contract
* Mints pufETH for the `recipient`, corresponding to the stETH amount deposited

*Requirements*
* Called must have previously approved the amount of wstETH to be sent to the `PufferDepositor` contract