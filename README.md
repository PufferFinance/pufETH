# pufETH Contract Suite

## Overview

In advance of Puffer's full mainnet launch, we are allowing early adopters to deposit stETH into our vault and earn points for staking on EigenLayer via EigenLayer's referral program. Users who do not hold stETH may also easily participate as our frontend will allow swapping other tokens for stETH and depositing into our vault. In return, depositers will receive pufETH, which will appreciate as the underlying stETH in our vault accrues value. In addition, this received pufETH is a liquid token that can be further utilized through some of our partnering protocols until and after the full Puffer mainnet launch.


## Puffer Mainnet Launch

Upon the full Puffer launch on mainnet, all of the staked stETH on EigenLayer will be withdrawn, and then will be converted back to ETH via Lido. This full process will take over a week (with the former taking perhaps a few days, and the latter taking a week). During this time, all deposits will be paused. After the withdrawal process is completed, the ETH will move from the vault into the PufferPool contract. It's purpose there will be to provide ETH for provisioning validators within the Puffer protocol. After this has been completed, deposits will be allowed again. This time, ETH or other tokens may be deposited (with other tokens being swapped to ETH), minting pufETH, and the ETH will back pufETH and help provide liquidity for provisioning validators. Now, pufETH will accrue in value as the Puffer protocol earns rewards and receives smoothing commitments. 


## Using This Repo

### Compile

```shell
$ forge build
```

### Test

```shell
$ forge test
```
