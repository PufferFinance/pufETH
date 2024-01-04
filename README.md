# pufETH Contract Suite

## Overview

Prior to Puffer's full mainnet launch, we are offering early adopters the opportunity to deposit stETH into our vault. This enables them to earn points for staking on EigenLayer via their referral program. Additionally, users without stETH can easily participate, as our interface supports swapping other tokens for stETH and depositing them into our vault. In exchange, depositors will receive pufETH, a token that appreciates in value as the underlying stETH in our vault grows. Importantly, pufETH is a liquid token that can be actively utilized within the DeFi ecosystem, including some of our partner protocols, both before and after the full Puffer mainnet launch.


## Puffer Mainnet Launch

Upon Puffer's full mainnet launch, all staked stETH on EigenLayer will be withdrawn and subsequently converted to ETH via Lido. This entire process is expected to span over a week, with the withdrawal taking a few days and the conversion to ETH around a week. During this phase, stETH deposits will be discontinued, and instead only ETH deposits (or token-to-ETH conversions) will be allowed. Depositors will still receive pufETH, as usual. Following the withdrawal process, all ETH will be transferred from the vault to the PufferPool contract. The primary role of this ETH on the PufferPool contract is to facilitate the provisioning of validators within the Puffer protocol. As the protocol generates rewards and secures smoothing commitments, the value of pufETH will correspondingly appreciate.


## Using This Repo

### Compile

```shell
$ forge build
```

### Test

```shell
$ forge test
```
