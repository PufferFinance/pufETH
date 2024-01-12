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

### [PufferDepositor](./PufferDepositor.md)

| File | Type | Upgradeable | Inherited | Deployed |
| -------- | -------- | -------- | -------- | -------- |
| [`IPufferDepositor.sol`](../src/interface/IPufferDepositor.sol) | Singleton | / | YES | / |
| [`PufferDepositor.sol`](../src/PufferDepositor.sol) | Singleton | / | YES | / |

These contracts support depositing into our vault, and allow swapping other assets into depositable assets.

* Register validator public keys
* Deposit an ETH bond, which gets converted to pufETH and held within the [`PufferProtocol.sol`](../src/PufferProtocol.sol) contract 
* Pay the initial smoothing commitment, and also additional smoothing commitments to extend the duration of running their validator
* Receive 32 provisioned ETH to run a validator
* Stop running their validator and retrieve their bond

The protocol also utilizes these smart contracts to perform important functions, such as:

* Proof of Reserves, AKA the amount of ETH backing pufETH
* Proof of Full Withdrawls, required for NoOps to be able to retrieve their bond after they have finished validating
* Create new Puffer Modules, which will include various mixes of AVSs that NoOps can decide to opt into, depending on risk/reward preferences
* Store information about validators and protocol state variables controlled by governance, such as the ratio at which withdrawn ETH is split between the [PufferPool](../src/PufferPool.sol) and [WithdrawalPool](../src/WithdrawalPool.sol) smart contracts

See full documentation in [./PufferProtocol.md](./PufferProtocol.md)

### [Guardians](./Guardians.md)

| File | Type | Upgradeable | Inherited | Deployed |
| -------- | -------- | -------- | -------- | -------- |
| [`IGuardianModule.sol`](../src/interface/IGuardianModule.sol) | Singleton | / | YES | / |
| [`IEnclaveVerifier.sol`](../src/interface/IEnclaveVerifier.sol) | Singleton | / | YES |/ |
| [`EnclaveVerifier.sol`](../src/EnclaveVerifier.sol) | Singleton | NO | YES | / |
| [`GuardianModule.sol`](../src/GuardianModule.sol) | Singleton | NO | NO | / |

The Guardians are a collective of respected community members who are deeply aligned with Ethereum's principles and values. They perform some trusted operations for our protocol, including:

* Reporting the amount of ETH backing pufETH
* Ejecting validators

See full documentation in [./Guardians.md](./Guardians.md)

### [Modules](./Modules.md)

| File | Type | Upgradeable | Inherited | Deployed |
| -------- | -------- | -------- | -------- | -------- |
| [`IPufferModule.sol`](../src/interface/IPufferModule.sol) | Singleton | / | YES | / |
| [`NoRestakingModule.sol`](../src/NoRestakingModule.sol) | Singleton | NO | NO | / |
| [`PufferModule.sol`](../src/PufferModule.sol) | [Beacon Proxy](https://docs.openzeppelin.com/contracts/5.x/api/proxy#BeaconProxy) | YES | NO | / |

Each Puffer Module refers to a specific set of AVSs for which all Puffer NoOps participating in that module must delegate their funds to running. Each validator must choose exactly one Puffer Module to participate in, based on desired risk/reward preferences. The safest Puffer Module is the [NoRestakingModule](../src/NoRestakingModule.sol), which includes no AVSs. Validators in this module only perform Ethereum consensus.

See full documentation in [./PufferModule.md](./PufferModule.md)

### [PufferPool](./PufferPool.md)

| File | Type | Upgradeable | Inherited | Deployed |
| -------- | -------- | -------- | -------- |  -------- |
| [`TokenRescuer.sol`](../src/TokenRescuer.sol) | Singleton | NO | Yes | / |
| [`IPufferPool.sol`](../src/interface/IPufferPool.sol) | Singleton | NO | Yes | / |
| [`PufferPool.sol`](../src/PufferPool.sol) | Singleton | NO | / | / |

The [PufferPool](../src/PufferPool.sol) contract is where the main funds are held before provisioning validators. Stakers deposit ETH into this contract in exchange for pufETH. Protocol rewards may also be sent to this contract, which will ultimately appreciate the value of pufETH.

See full documentation in [./PufferPool.md](./PufferPool.md)

### [WithdrawalPool](./WithdrawalPool.md)

| File | Type | Upgradeable | Inherited | Deployed |
| -------- | -------- | -------- | -------- |  -------- |
| [`IWithdrawalPool.sol`](../src/interface/IWithdrawalPool.sol) | Singleton | NO | YES | / |
| [`WithdrawalPool.sol`](../src/WithdrawalPool.sol) | Singleton | NO | / | / |

pufETH holders who wish to exchange their holdings for ETH may do so via the [WithdrawalPool](../src/WithdrawalPool.sol) contract, given there is enough liquidity to fulfill the exchange. This contract receives funds when Puffer NoOps discontinue running their validators and return the ETH back to the protocol. Some of this ETH enters the [WithdrawalPool](../src/WithdrawalPool.sol) contract according to a ratio determined by governance. 

See full documentation in [./WithdrawalPool.md](./WithdrawalPool.md)
