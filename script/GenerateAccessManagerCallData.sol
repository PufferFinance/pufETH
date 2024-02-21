// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { Script } from "forge-std/Script.sol";
import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";
import { Multicall } from "openzeppelin/utils/Multicall.sol";
import { console } from "forge-std/console.sol";
import { PufferVaultMainnet } from "../src/PufferVaultMainnet.sol";
import { PufferDepositorMainnet } from "../src/PufferDepositorMainnet.sol";
import { PUBLIC_ROLE, ROLE_ID_DAO, ROLE_ID_PUFFER_PROTOCOL } from "./Roles.sol";

/**
 * @title GenerateAccessManagerCallData
 * @author Puffer Finance
 * @notice Generates the AccessManager call data to setup the public access
 * The returned calldata is queued and executed by the Operations Multisig
 * 1. timelock.queueTransaction(address(accessManager), encodedMulticall, 1)
 * 2. ... 7 days later ...
 * 3. timelock.executeTransaction(address(accessManager), encodedMulticall, 1)
 */
contract GenerateAccessManagerCallData is Script {
    function run(address pufferVaultProxy, address pufferDepositorProxy, address pufferProtocolProxy)
        public
        pure
        returns (bytes memory)
    {
        // Public selectors for PufferVault
        bytes4[] memory publicSelectors = new bytes4[](5);
        publicSelectors[0] = PufferVaultMainnet.withdraw.selector;
        publicSelectors[1] = PufferVaultMainnet.redeem.selector;
        publicSelectors[2] = PufferVaultMainnet.depositETH.selector;
        publicSelectors[3] = PufferVaultMainnet.depositStETH.selector;
        publicSelectors[4] = PufferVaultMainnet.burn.selector;
        // `deposit` and `mint` are already `restricted` and allowed for PUBLIC_ROLE (PufferVault deployment)

        bytes memory publicSelectorsCallData = abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector, pufferVaultProxy, publicSelectors, PUBLIC_ROLE
        );

        // PufferDepositor public selectors
        bytes4[] memory publicSelectorsDepositor = new bytes4[](2);
        publicSelectorsDepositor[0] = PufferDepositorMainnet.depositStETH.selector;
        publicSelectorsDepositor[1] = PufferDepositorMainnet.depositWstETH.selector;

        bytes memory publicSelectorsCallDataDepositor = abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector, pufferDepositorProxy, publicSelectorsDepositor, PUBLIC_ROLE
        );

        //@todo cleanup of old public selectors on the depositor smart contract

        // DAO selectors
        bytes4[] memory daoSelectors = new bytes4[](1);
        daoSelectors[0] = PufferVaultMainnet.setDailyWithdrawalLimit.selector;

        bytes memory daoSelectorsCallData = abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector, pufferVaultProxy, daoSelectors, ROLE_ID_DAO
        );

        // Puffer Protocol only
        bytes4[] memory protocolSelectors = new bytes4[](2);
        protocolSelectors[0] = PufferVaultMainnet.burn.selector;
        protocolSelectors[1] = PufferVaultMainnet.transferETH.selector;

        bytes memory protocolSelectorsCalldata = abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector,
            pufferProtocolProxy,
            protocolSelectors,
            ROLE_ID_PUFFER_PROTOCOL
        );

        bytes[] memory calldatas = new bytes[](4);

        // Combine the two calldatas
        calldatas[0] = publicSelectorsCallData;
        calldatas[1] = daoSelectorsCallData;
        calldatas[2] = protocolSelectorsCalldata;
        calldatas[3] = publicSelectorsCallDataDepositor;

        bytes memory encodedMulticall = abi.encodeCall(Multicall.multicall, (calldatas));

        // console.log("GenerateAccessManagerCallData:");
        // console.logBytes(encodedMulticall);

        return encodedMulticall;
    }
}
