// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

// Operations & Community multisig have this role
// Operations with 7 day delay, Community 0
// Deprecated
uint64 constant ROLE_ID_UPGRADER = 1;

// Role assigned to Operations Multisig
uint64 constant ROLE_ID_OPERATIONS_MULTISIG = 22;
uint64 constant ROLE_ID_OPERATIONS_PAYMASTER = 23;
uint64 constant ROLE_ID_OPERATIONS_COORDINATOR = 24;

// Role assigned to the Puffer Protocol
uint64 constant ROLE_ID_PUFFER_PROTOCOL = 1234;
uint64 constant ROLE_ID_DAO = 77;
uint64 constant ROLE_ID_GUARDIANS = 88;
uint64 constant ROLE_ID_PUFFER_ORACLE = 999;

// Public role (defined in AccessManager.sol)
uint64 constant PUBLIC_ROLE = type(uint64).max;
// Admin role (defined in AccessManager.sol) (only Timelock.sol must have this role)
uint64 constant ADMIN_ROLE = 0;

// Allowlister role for AVSContractsRegistry
uint64 constant ROLE_ID_AVS_COORDINATOR_ALLOWLISTER = 5;
