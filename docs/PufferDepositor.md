# PufferDepositor

### [PufferDepositor](./PufferDepositor.md)

| File | Type | Upgradeable | Inherited | Deployed |
| -------- | -------- | -------- | -------- | -------- |
| [`IPufferDepositor.sol`](../src/interface/IPufferDepositor.sol) | Singleton | / | YES | / |
| [`PufferDepositor.sol`](../src/PufferDepositor.sol) | Singleton | UUPS Proxy | NO | / |
| [`PufferDepositorStorage.sol`](../src/PufferDepositorStorage.sol) | Singleton | UUPS Proxy | YES | / |

The PufferDepositor facilitates deposits into the [PufferVault](./PufferVault.md), as well as swapping other tokens for depositable assets

#### High-level Concepts

This document organizes methods according to the following themes (click each to be taken to the relevant section):
* [Deposit Functions](#deposit-functions)

#### Important state variables

The only state information the PufferDepositor contract holds are the addresses of stETH and wrapped stETH, as well as the SushiSwap Router contract, which the PufferDepositor uses for swapping other tokens into depositable assets.

* `ISushiRouter internal constant _SUSHI_ROUTER`: The address of the SushiSwap Router contract, used to facilitate swapping other assets into depositable assets (either stETH or WETH)

---

### Deposit Functions

#### `swapAndDeposit`

```solidity
function swapAndDeposit(address tokenIn, uint256 amountIn, uint256 amountOutMin, bytes calldata routeCode)
    public
    virtual
    returns (uint256 pufETHAmount)
```

This function allows for swapping a token to stETH, and depositing the received stETH into the `PufferVault` smart contract

*Effects*
* Takes the specified `amountIn` amount of `tokenIn` from the caller
* Swaps the input token for stETH, receiving at least the specified `amountOutMin` of stETH, otherwise reverting
* Deposits the newly received stETH resulting from the swap into the `PufferVault` contract
* Mints a corresponding amount of pufETH token to the caller, based on the amount of assets deposited

*Requirements* 
* The provided `routeCode` calldata must correspond to a proper sequence of assets to swap through, that can result in receiving the specified `amountOutMin` amount of stETH, otherwise the function call will revert
* The caller must have previously approved the `amountIn` of `tokenIn` token to be taken by this `PufferDepositor` contract

#### `swapAndDepositWithPermit`

```solidity
function swapAndDepositWithPermit(
    address tokenIn,
    uint256 amountOutMin,
    IPufferDepositor.Permit calldata permitData,
    bytes calldata routeCode
) public virtual returns (uint256 pufETHAmount)
```

This function is the same as above, except it does not require a preceding transaction to approve the token to be swapped

*Effects* 
* Takes the specified `amountIn` amount of `tokenIn` from the caller
* Swaps the input token for stETH, receiving at least the specified `amountOutMin` of stETH, otherwise reverting
* Deposits the newly received stETH resulting from the swap into the `PufferVault` contract
* Mints a corresponding amount of pufETH token to the caller, based on the amount of assets deposited

*Requirements*
* The provided `routeCode` calldata must correspond to a proper sequence of assets to swap through, that can result in receiving the specified `amountOutMin` amount of stETH, otherwise the function call will revert

#### `depositWstETH`

```solidity
function depositWstETH(IPufferDepositor.Permit calldata permitData) external returns (uint256 pufETHAmount)
```

Allows the depositing of wrapped stETH into the `PufferVault` contract. It will unwrap the provided wstETH into stETH and then deposit into the `PufferVault`

*Effects*
* Takes the specified amount of wrapped stETH from the caller
* Unwraps the provided wrapped stETH into stETH
* Deposits the newly unwrapped stETH into the `PufferVault` contract
* Mints pufETH to the caller, corresponding to the asset amount deposited

*Requirements*
* Called must have previously approved the amount of wrapped stETH to be taken by the `PufferDepositor` contract