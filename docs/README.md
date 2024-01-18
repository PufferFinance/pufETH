# pufETH Docs

## Overview

pufETH is a native liquid restaking token (nLRT) that is undergoing development. Before Puffer's mainnet launch, pufETH holders will earn LST yield, Puffer points, and may participate in DeFi all without lockups. 

Prior to Puffer's full mainnet launch, users have the opportunity to deposit stETH into the [PufferVault](./PufferVault.md) to participate in Puffer's early adopter program. Additionally, users without stETH can easily participate, as the contract supports swapping tokens to stETH before depositing. In exchange, depositors receive pufETH which appreciates in value as the underlying stETH in the contract accrues. 

The PufferVault's stETH will be deposited into EigenLayer's stETH strategy contract if it has not reached it's cap.

## Puffer Mainnet Launch

Upon Puffer's full mainnet launch, stETH will be withdrawn from EigenLayer and then converted to ETH via Lido. This entire process is expected to span over a ~10 day period. During this period, depositors can continue to mint pufETH, but the contract will switch to accept ETH & WETH deposits.

Following the withdrawal process, the ETH will be utilized to provision decentralized Ethereum validators within the Puffer protocol. This marks a transition from Lido LST rewards to Puffer Protocol rewards. Importantly, nothing needs to be done by pufETH holders! However, as the Puffer protocol operates, pufETH value is expected to increase faster as the token now captures both PoS and restaking rewards.


## Dependencies

- [Openzeppelin smart contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
    - AccessManager
    - IERC20
    - ERC20Permit
    - SafeERC20
    - ERC1967Proxy
    - IERC721Receiver
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
| [`PufferVaultStorage.sol`](../src/PufferVaultStorage.sol) | Singleton | UUPS Proxy | YES | / |

The Puffer Vault is the contract in charge of holding funds for the Puffer Protocol. Initially, it will store stETH and deposit into EigenLayer. Then, once the Puffer mainnet launch happens, it will withdraw this stETH and hold ETH instead, which will be used to provision validators for the Puffer Protocol.

See full documentation in [./PufferVault.md](./PufferVault.md)

### [PufferDepositor](./PufferDepositor.md)

| File | Type | Upgradeable | Inherited | Deployed |
| -------- | -------- | -------- | -------- | -------- |
| [`IPufferDepositor.sol`](../src/interface/IPufferDepositor.sol) | Singleton | / | YES | / |
| [`PufferDepositor.sol`](../src/PufferDepositor.sol) | Singleton | UUPS Proxy | NO | / |
| [`PufferDepositorStorage.sol`](../src/PufferDepositorStorage.sol) | Singleton | UUPS Proxy | YES | / |

These contracts support depositing into our vault, and allow swapping other assets into depositable assets.

See full documentation in [./PufferDepositor.md](./PufferDepositor.md)

### [PufferOracle](./PufferOracle.md)

| File | Type | Upgradeable | Inherited | Deployed |
| -------- | -------- | -------- | -------- | -------- |
| [`PufferOracle.sol`](../src/PufferOracle.sol) | Singleton | / | NO | / |

This contract allows Guardians to post Proof of Reserves, proving the amount of ETH backing pufETH, and therefore establishing a fair market value of pufETH.

See full documentation in [./PufferOracle.md](./PufferOracle.md)
