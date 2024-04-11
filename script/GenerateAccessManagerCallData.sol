// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { Script } from "forge-std/Script.sol";
import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";
import { Multicall } from "openzeppelin/utils/Multicall.sol";
import { console } from "forge-std/console.sol";
import { PufferVaultV2 } from "../src/PufferVaultV2.sol";
import { PufferDepositorV2 } from "../src/PufferDepositorV2.sol";
import { PufferDepositor } from "../src/PufferDepositor.sol";
import { PUBLIC_ROLE, ROLE_ID_DAO, ROLE_ID_PUFFER_PROTOCOL, ROLE_ID_OPERATIONS_MULTISIG } from "./Roles.sol";

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
    function run(address pufferVaultProxy, address pufferDepositorProxy) public pure returns (bytes memory) {
        bytes[] memory calldatas = new bytes[](5);

        // Combine the two calldatas
        calldatas[0] = _getPublicSelectorsCalldata({ pufferVaultProxy: pufferVaultProxy });
        calldatas[1] = _getDaoSelectorsCalldataCalldata({ pufferVaultProxy: pufferVaultProxy });
        calldatas[2] = _getProtocolSelectorsCalldata({ pufferVaultProxy: pufferVaultProxy });
        calldatas[3] = _getOperationsSelectorsCalldata({ pufferVaultProxy: pufferVaultProxy });
        calldatas[4] = _getPublicSelectorsForDepositor({ pufferDepositorProxy: pufferDepositorProxy });

        bytes memory encodedMulticall = abi.encodeCall(Multicall.multicall, (calldatas));

        // console.log("GenerateAccessManagerCallData:");
        // console.logBytes(encodedMulticall);

        return encodedMulticall;
    }

    function _getPublicSelectorsCalldata(address pufferVaultProxy) internal pure returns (bytes memory) {
        // Public selectors for PufferVault
        bytes4[] memory publicSelectors = new bytes4[](4);
        publicSelectors[0] = PufferVaultV2.withdraw.selector;
        publicSelectors[1] = PufferVaultV2.redeem.selector;
        publicSelectors[2] = PufferVaultV2.depositETH.selector;
        publicSelectors[3] = PufferVaultV2.depositStETH.selector;
        // `deposit` and `mint` are already `restricted` and allowed for PUBLIC_ROLE (PufferVault deployment)

        return abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector, pufferVaultProxy, publicSelectors, PUBLIC_ROLE
        );
    }

    function _getDaoSelectorsCalldataCalldata(address pufferVaultProxy) internal pure returns (bytes memory) {
        // DAO selectors
        bytes4[] memory daoSelectors = new bytes4[](1);
        daoSelectors[0] = PufferVaultV2.setDailyWithdrawalLimit.selector;

        return abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector, pufferVaultProxy, daoSelectors, ROLE_ID_DAO
        );
    }

    function _getProtocolSelectorsCalldata(address pufferVaultProxy) internal pure returns (bytes memory) {
        // Puffer Protocol only
        // PufferProtocol will get `ROLE_ID_PUFFER_PROTOCOL` when it's deployed
        bytes4[] memory protocolSelectors = new bytes4[](2);
        protocolSelectors[0] = PufferVaultV2.transferETH.selector;
        protocolSelectors[1] = PufferVaultV2.burn.selector;

        return abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector, pufferVaultProxy, protocolSelectors, ROLE_ID_PUFFER_PROTOCOL
        );
    }

    function _getOperationsSelectorsCalldata(address pufferVaultProxy) internal pure returns (bytes memory) {
        // Operations multisig
        bytes4[] memory operationsSelectors = new bytes4[](3);
        operationsSelectors[0] = PufferVaultV2.initiateETHWithdrawalsFromLido.selector;
        operationsSelectors[1] = PufferVaultV2.claimWithdrawalsFromLido.selector;
        operationsSelectors[2] = PufferVaultV2.claimWithdrawalFromEigenLayerM2.selector;

        return abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector,
            pufferVaultProxy,
            operationsSelectors,
            ROLE_ID_OPERATIONS_MULTISIG
        );
    }

    function _getPublicSelectorsForDepositor(address pufferDepositorProxy) internal pure returns (bytes memory) {
        // PufferDepositor public selectors
        bytes4[] memory publicSelectorsDepositor = new bytes4[](2);
        publicSelectorsDepositor[0] = PufferDepositorV2.depositStETH.selector;
        publicSelectorsDepositor[1] = PufferDepositorV2.depositWstETH.selector;

        return abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector, pufferDepositorProxy, publicSelectorsDepositor, PUBLIC_ROLE
        );
    }
}
