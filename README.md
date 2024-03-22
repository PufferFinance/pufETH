# <h1 align="center"> Puffer Vault </h1>
[![Website][Website-badge]][Website] [![Docs][docs-badge]][docs]
  [![Discord][discord-badge]][discord] [![X][X-badge]][X] [![Foundry][foundry-badge]][foundry]

[Website-badge]: https://img.shields.io/badge/WEBSITE-8A2BE2
[Website]: https://www.puffer.fi
[X-badge]: https://img.shields.io/twitter/follow/puffer_finance
[X]: https://twitter.com/puffer_finance
[discord]: https://discord.gg/pufferfi
[docs-badge]: https://img.shields.io/badge/DOCS-8A2BE2
[docs]: https://docs.puffer.fi/
[discord-badge]: https://dcbadge.vercel.app/api/server/pufferfi?style=flat
[gha]: https://github.com/PufferFinance/PufferPool/actions
[gha-badge]: https://github.com/PufferFinance/PufferPool/actions/workflows/ci.yml/badge.svg
[foundry]: https://getfoundry.sh
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

## Overview

Prior to Puffer's full mainnet launch, users have the opportunity to deposit stETH to earn rewards from Puffer and EigenLayer's early adopter programs. Additionally, users without stETH can easily participate, as the contract supports swapping tokens to stETH before depositing.

In exchange, depositors receive pufETH, a yield-bearing ERC20 token that appreciates in value as the underlying stETH in the contract accrues. Importantly, pufETH is a liquid token meaning users earn stETH yield, Puffer points, and EigenLayer points all without lockups. This token can be held, traded, or utilized throughout DeFi both before and after the full Puffer mainnet launch.


## Puffer Mainnet Launch

Upon Puffer's full mainnet launch, stETH will be withdrawn from EigenLayer and then converted to ETH via Lido. This entire process is expected to span over an ~10 day period. During this period, depositors can continue to mint pufETH, but the contract will switch to accept ETH deposits or token-to-ETH deposits.

Following the withdrawal process, the ETH will be utilized to provision decentralized Ethereum validators within the Puffer protocol. This marks a transition from Lido LST rewards to Puffer Protocol rewards. Importantly, nothing needs to be done by pufETH holders! However, as the Puffer protocol operates, pufETH value is expected to increase faster as the token now captures both PoS and restaking rewards.

## Contract addresses
- PufferVault (pufETH token): 0xD9A442856C234a39a81a089C06451EBAa4306a72
- PufferDepositor: 0x4aA799C5dfc01ee7d790e3bf1a7C2257CE1DcefF
- AccessManager: 0x8c1686069474410E6243425f4a10177a94EBEE11
- Timelock: 0x3C28B7c7Ba1A1f55c9Ce66b263B33B204f2126eA

## Audits
- [BlockSec](./audits/BlockSec-pufETH-v1.pdf)
- [SlowMist](./audits/SlowMist-pufETH-v1.pdf)
- [Quantstamp](./audits/Quantstamp-pufETH-v1.pdf)

# Tests

<strong>Make sure you have access to a valid archive node RPC for ETH Mainnet (e.g. Infura)</strong>

Installing dependencies and running tests can be executed running:
```
ETH_RPC_URL=https://mainnet.infura.io/v3/YOUR_KEY forge test -vvvv
```

# Echidna
To install Echidna, see the instructions [here](https://github.com/crytic/echidna). To use Echidna, run the following command from the project's root:
```bash
forge install crytic/properties --no-commit
echidna . --contract EchidnaPufferVaultV2 --config src/echidna/config.yaml
```
For more information see the properties [README](https://github.com/crytic/properties/tree/main).

