// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { Script } from "forge-std/Script.sol";
import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";
import { Multicall } from "openzeppelin/utils/Multicall.sol";
import { console } from "forge-std/console.sol";
import { PufferVaultMainnet } from "../src/PufferVaultMainnet.sol";
import { PUBLIC_ROLE, ROLE_ID_DAO } from "./Roles.sol";

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
    function run(address pufferVaultProxy) public pure returns (bytes memory) {
        bytes[] memory calldatas = new bytes[](2);

        // Public selectors
        bytes4[] memory publicSelectors = new bytes4[](6);
        publicSelectors[0] = PufferVaultMainnet.withdraw.selector;
        publicSelectors[1] = PufferVaultMainnet.redeem.selector;
        publicSelectors[2] = PufferVaultMainnet.redeem.selector;
        publicSelectors[3] = PufferVaultMainnet.depositETH.selector;
        publicSelectors[4] = PufferVaultMainnet.depositStETH.selector;
        publicSelectors[5] = PufferVaultMainnet.burn.selector;
        // `deposit` and `mint` are already `restricted` and allowed for PUBLIC_ROLE (PufferVault deployment)

        bytes memory publicSelectorsCallData = abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector, pufferVaultProxy, publicSelectors, PUBLIC_ROLE
        );

        // DAO selectors
        bytes4[] memory daoSelectors = new bytes4[](1);
        daoSelectors[0] = PufferVaultMainnet.setDailyWithdrawalLimit.selector;

        bytes memory daoSelectorsCallData = abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector, pufferVaultProxy, daoSelectors, ROLE_ID_DAO
        );

        //@todo We are missing `transferETH`, `burn` authorization for PufferProtocol

        // Combine the two calldatas
        calldatas[0] = publicSelectorsCallData;
        calldatas[1] = daoSelectorsCallData;

        bytes memory encodedMulticall = abi.encodeCall(Multicall.multicall, (calldatas));

        // console.log("GenerateAccessManagerCallData:");
        // console.logBytes(encodedMulticall);

        return encodedMulticall;

        // the returned calldata is supposed to be called like this
        // manager.multicall(calldatas);
    }
}
