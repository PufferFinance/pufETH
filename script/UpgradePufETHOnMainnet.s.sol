// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { ERC1967Proxy } from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { BaseScript } from "./BaseScript.s.sol";
import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";
import { PufferDepositorV2 } from "../src/PufferDepositorV2.sol";
import { PufferVaultV2 } from "../src/PufferVaultV2.sol";
import { Timelock } from "../src/Timelock.sol";
import { NoImplementation } from "../src/NoImplementation.sol";
import { PufferDeployment } from "../src/structs/PufferDeployment.sol";
import { IEigenLayer } from "../src/interface/EigenLayer/IEigenLayer.sol";
import { IStrategy } from "../src/interface/EigenLayer/IStrategy.sol";
import { IDelegationManager } from "../src/interface/EigenLayer/IDelegationManager.sol";
import { IStETH } from "../src/interface/Lido/IStETH.sol";
import { ILidoWithdrawalQueue } from "../src/interface/Lido/ILidoWithdrawalQueue.sol";
import { stETHMock } from "../test/mocks/stETHMock.sol";
import { LidoWithdrawalQueueMock } from "../test/mocks/LidoWithdrawalQueueMock.sol";
import { stETHStrategyMock } from "../test/mocks/stETHStrategyMock.sol";
import { EigenLayerManagerMock } from "../test/mocks/EigenLayerManagerMock.sol";
import { UUPSUpgradeable } from "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IWETH } from "../src/interface/Other/IWETH.sol";
import { WETH9 } from "../test/mocks/WETH9.sol";
import { ROLE_ID_UPGRADER, ROLE_ID_OPERATIONS_MULTISIG } from "./Roles.sol";
import { IPufferOracle } from "../src/interface/IPufferOracle.sol";

/**
 * @title UpgradePufETHOnMainnet
 * @author Puffer Finance
 * @notice Deploys PufferPoolV2 and Contracts
 * @dev
 *
 *
 *         NOTE:
 *
 *         If you ran the deployment script, but did not `--broadcast` the transaction, it will still update your local chainId-deployment.json file.
 *         Other scripts will fail because addresses will be updated in deployments file, but the deployment never happened.
 *
 *         BaseScript.sol holds the private key logic, if you don't have `PK` ENV variable, it will use the default one PK from `makeAddr("pufferDeployer")`
 *
 *         PK=${deployer_pk} forge script script/DeployPufETH.s.sol:DeployPufETH -vvvv --rpc-url=... --broadcast
 */
contract UpgradePufETHOnMainnet is BaseScript {
    /**
     * @dev Ethereum Mainnet addresses
     */

    // Puffer
    address PUFFER_VAULT_PROXY = 0xD9A442856C234a39a81a089C06451EBAa4306a72;
    address PUFFER_DEPOSITOR_PROXY = 0x4aA799C5dfc01ee7d790e3bf1a7C2257CE1DcefF;

    IPufferOracle PUFFER_ORACLE = IPufferOracle(address(11)); // TBD
    AccessManager ACCESS_MANAGER = AccessManager(0x8c1686069474410E6243425f4a10177a94EBEE11);

    // WETH
    IWETH WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // Lido
    IStETH ST_ETH = IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    ILidoWithdrawalQueue LIDO_WITHDRAWAL_QUEUE = ILidoWithdrawalQueue(0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1);

    // EigenLayer
    IDelegationManager DELEGATION_MANAGER = IDelegationManager(0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A);
    IStrategy STETH_STRATEGY = IStrategy(0x93c4b944D05dfe6df7645A86cd2206016c51564D);
    IEigenLayer EIGEN_STRATEGY_MANAGER = IEigenLayer(0x858646372CC42E1A627fcE94aa7A7033e7CF075A);

    function run() public broadcast {
        // Deploy implementation contracts
        PufferVaultV2 pufferVaultImplementation = new PufferVaultV2({
            stETH: ST_ETH,
            weth: WETH,
            lidoWithdrawalQueue: LIDO_WITHDRAWAL_QUEUE,
            stETHStrategy: STETH_STRATEGY,
            eigenStrategyManager: EIGEN_STRATEGY_MANAGER,
            oracle: PUFFER_ORACLE,
            delegationManager: DELEGATION_MANAGER
        });
        vm.label(address(pufferVaultImplementation), "PufferVaultImplementation");

        PufferDepositorV2 pufferDepositorImplementation =
            new PufferDepositorV2({ stETH: ST_ETH, pufferVault: PufferVaultV2(payable(PUFFER_VAULT_PROXY)) });
        vm.label(address(pufferDepositorImplementation), "PufferDepositorImplementation");

        bytes memory pufferVaultUpgradeCalldata = abi.encodeWithSelector(
            UUPSUpgradeable.upgradeToAndCall.selector,
            address(pufferVaultImplementation),
            abi.encodeCall(PufferVaultV2.initialize, ())
        );
        bytes memory pufferDepositorUpgradeCalldata = abi.encodeWithSelector(
            UUPSUpgradeable.upgradeToAndCall.selector, address(pufferDepositorImplementation), ""
        );

        bytes[] memory accessManagerCalldata = new bytes[](2);
        accessManagerCalldata[0] =
            abi.encodeWithSelector(AccessManager.execute.selector, PUFFER_VAULT_PROXY, pufferVaultUpgradeCalldata);
        accessManagerCalldata[1] = abi.encodeWithSelector(
            AccessManager.execute.selector, PUFFER_DEPOSITOR_PROXY, pufferDepositorUpgradeCalldata
        );

        bytes[] memory timeLockCalldata = new bytes[](2);
        timeLockCalldata[0] = abi.encodeWithSelector(
            Timelock.queueTransaction.selector, address(ACCESS_MANAGER), accessManagerCalldata[0]
        );
        timeLockCalldata[1] = abi.encodeWithSelector(
            Timelock.queueTransaction.selector, address(ACCESS_MANAGER), accessManagerCalldata[1]
        );

        console.log("TimeLock PufferVaultV2 Upgrade Calldata");
        console.logBytes(timeLockCalldata[0]);

        console.log("TimeLock PufferDepositorV2 Upgrade Calldata");
        console.logBytes(timeLockCalldata[1]);
    }
}
