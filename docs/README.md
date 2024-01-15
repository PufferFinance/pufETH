# pufETH Docs

## Overview

Prior to Puffer's full mainnet launch, users have the opportunity to deposit stETH to earn rewards from Puffer and EigenLayer's early adopter programs. Additionally, users without stETH can easily participate, as the contract supports swapping tokens to stETH before depositing.

In exchange, depositors receive pufETH, a yield-bearing ERC20 token that appreciates in value as the underlying stETH in the contract accrues. Importantly, pufETH is a liquid token meaning users earn stETH yield, Puffer points, and EigenLayer points all without lockups. This token can be held, traded, or utilized throughout DeFi both before and after the full Puffer mainnet launch.


## Puffer Mainnet Launch

Upon Puffer's full mainnet launch, stETH will be withdrawn from EigenLayer and then converted to ETH via Lido. This entire process is expected to span over an ~10 day period. During this period, depositors can continue to mint pufETH, but the contract will switch to accept ETH deposits or token-to-ETH deposits.

Following the withdrawal process, the ETH will be utilized to provision decentralized Ethereum validators within the Puffer protocol. This marks a transition from Lido LST rewards to Puffer Protocol rewards. Importantly, nothing needs to be done by pufETH holders! However, as the Puffer protocol operates, pufETH value is expected to increase faster as the token now captures both PoS and restaking rewards.


## Dependencies

- [Openzeppelin smart contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
    - AccessManager
    - IERC20
    - ERC20Permit
    - SafeERC20
    - ERC1967Proxy
    - IERC721Receiver
    - EnumerableSet
- [Openzeppelin upgradeable smart contracts](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable)
    - ERC4626Upgradeable
    - UUPSUpgradeable
    - AccessManagedUpgradeable
    - Initializable


## System components:

### [PufferVault](./PufferVault.md)

| File | Type | Upgradeable | Inherited | Deployed |
| -------- | -------- | -------- | -------- | -------- |
| [`IPufferVault.sol`](../src/interface/IPufferVault.sol) | Singleton | / | YES | / |
| [`PufferVault.sol`](../src/PufferVault.sol) | Singleton | UUPS Proxy | YES | / |
| [`PufferVaultMainnet.sol`](../src/PufferVaultMainnet.sol) | Singleton | UUPS Proxy | NO | / |
| [`PufferVaultStorage.sol`](../src/PufferVaultStorage.sol) | Singleton | UUPS Proxy | NO | / |

The Puffer Vault is the contract in charge of holding funds for the Puffer Protocol. Initially, it will store stETH and deposit into EigenLayer. Then, once the Puffer mainnet launch happens, it will withdraw this stETH and hold ETH instead, which will be used to provision validators for the Puffer Protocol.

See full documentation in [./PufferVault.md](./PufferVault.md)

### [PufferDepositor](./PufferDepositor.md)

| File | Type | Upgradeable | Inherited | Deployed |
| -------- | -------- | -------- | -------- | -------- |
| [`IPufferDepositor.sol`](../src/interface/IPufferDepositor.sol) | Singleton | / | YES | / |
| [`PufferDepositor.sol`](../src/PufferDepositor.sol) | Singleton | UUPS Proxy | NO | / |
| [`PufferDepositorStorage.sol`](../src/PufferDepositorStorage.sol) | Singleton | UUPS Proxy | NO | / |

These contracts support depositing into our vault, and allow swapping other assets into depositable assets.

See full documentation in [./PufferDepositor.md](./PufferDepositor.md)

### [PufferOracle](./PufferOracle.md)

| File | Type | Upgradeable | Inherited | Deployed |
| -------- | -------- | -------- | -------- | -------- |
| [`PufferOracle.sol`](../src/PufferOracle.sol) | Singleton | / | NO | / |

This contract allows Guardians to post Proof of Reserves, proving the amount of ETH backing pufETH, and therefore establishing a fair market value of pufETH.

See full documentation in [./PufferOracle.md](./PufferOracle.md)
