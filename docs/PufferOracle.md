# PufferOracle

| File | Type | Upgradeable | Inherited | Deployed |
| -------- | -------- | -------- | -------- | -------- |
| [`PufferOracle.sol`](../src/PufferOracle.sol) | Singleton | / | NO | / |

This contract allows Guardians to post Proof of Reserves, proving the amount of ETH backing pufETH, and therefore establishing a fair market value of pufETH

#### High-level Concepts

This document organizes methods according to the following themes (click each to be taken to the relevant section):
* [Proof of Reserves](#proof-of-reserves)

#### Helpful Definitions

* Proof of Reserves: The protocol will regularly post the amount of ETH under its control, which corresponds to the amount of assets backing the pufETH token. Initially this will be done via a trusted party, but eventually Puffer will move to a trustless solution

#### Important state variables

The PufferOracle contract maintains state variables related to the amount of ETH backing the pufETH token. The important state variables are described below:

* `uint256 internal constant _UPDATE_INTERVAL`: Defines an interval of blocks that Proof of Reserves may not be posted twice within. For example, if the interval is 10 blocks, and Proof of Reserves was posted on block 1, then Proof of Reserves may not be posted again until block 11
* `uint256 ethAmount`: The amount of ETH that is not locked in the beacon chain, corresponding to a running validator. This could be ETH that lives within the `PufferVault` in the form of stETH or WETH or it could also correspond to stETH locked in EigenLayer's stETH strategy contract
* `uint256 lockedETH`: The amount of ETH that is locked in the beacon chain, correpsonding to a running validator
* `uint256 pufETHTotalSupply`: The total outstanding amount of pufETH
* `uint256 lastUpdate`: The last block for which Proof of Reserves was posted

---

### Proof of Reserves

#### `proofOfReserve`

```solidity
function proofOfReserve(
    uint256 newEthAmountValue,
    uint256 newLockedEthValue,
    uint256 pufETHTotalSupplyValue, // @todo what to do with this?
    uint256 blockNumber,
    uint256 numberOfActiveValidators,
    bytes[] calldata guardianSignatures
) external
```

This is the function that Guardians will call to update the total amount of ETH backing pufETH. This may directly impact the exchange rate of pufETH to ETH, setting the fair market value of pufETH.

*Effects*
* Changes the following state variables to the supplied values:
    * `ethAmount`
    * `lockedETH`
    * `pufETHTotalSupply`
    * `lastUpdate`

*Requirements*
* Must be called by Guardians
* Guardian signatures must be valid
* Must have enough Guardian signatures to meet threshold