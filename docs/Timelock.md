# Timelock

### Overview

These Puffer contracts implement a timelock such that actions cannot be taken to change the functionality of the protocol without prior warning to users. To this end, we have a minimum lock time of 2 days for all sensitive actions, meaning nothing in the protocol can change without at least 2 days of prior notice. 

### Community and Operations Multisigs

There are two different multisigs that have the capabilities to upgrade the contract, pause the contract, or perform planned phases corresponding with our launch, such as depositing into EigenLayer's stETH strategy contract if their cap has not been reached, and redeeming stETH for ETH via Lido. These two multisigs are referred to as the community multisig and the operations multisig. The community multisig will consist of trusted partners and respected members of the Ethereum community. This multisig will intervene in the protocol if any issues are found, and is allowed to execute transactions within 2 days. The operations multisig will consist of the core Puffer team, and will have a variable time lock period, but is expected to have a longer period than the community multisig in general.