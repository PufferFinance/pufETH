// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { ERC1967Proxy } from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { BaseScript } from "script/BaseScript.s.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";
import { PufferDepositor } from "src/PufferDepositor.sol";
import { PufferOracle } from "src/PufferOracle.sol";
import { PufferVault } from "src/PufferVault.sol";
import { NoImplementation } from "src/NoImplementation.sol";
import { PufferDeployment } from "src/structs/PufferDeployment.sol";
import { IEigenLayer } from "src/interface/EigenLayer/IEigenLayer.sol";
import { IStrategy } from "src/interface/EigenLayer/IStrategy.sol";
import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";
import { IStETH } from "src/interface/Lido/IStETH.sol";
import { ILidoWithdrawalQueue } from "src/interface/Lido/ILidoWithdrawalQueue.sol";
import { TimelockController } from "openzeppelin/governance/TimelockController.sol";
import { StETHMockERC20 } from "test/mocks/stETHMock.sol";
import { LidoWithdrawalQueueMock } from "test/mocks/LidoWithdrawalQueueMock.sol";
import { stETHStrategyMock } from "test/mocks/stETHStrategyMock.sol";
import { EigenLayerManagerMock } from "test/mocks/EigenLayerManagerMock.sol";

/**
 * @title DeployPuffer
 * @author Puffer Finance
 * @notice Deploys PufferPool Contracts
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
 *         PK=${deployer_pk} forge script script/DeployPuffETH.s.sol:DeployPuffETH -vvvv --rpc-url=... --broadcast
 */
contract DeployPuffETH is BaseScript {
    /**
     * @dev Ethereum Mainnet addresses
     */
    IStrategy internal constant _EIGEN_STETH_STRATEGY = IStrategy(0x93c4b944D05dfe6df7645A86cd2206016c51564D);
    IEigenLayer internal constant _EIGEN_STRATEGY_MANAGER = IEigenLayer(0x858646372CC42E1A627fcE94aa7A7033e7CF075A);
    IStETH internal constant _ST_ETH = IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    ILidoWithdrawalQueue internal constant _LIDO_WITHDRAWAL_QUEUE =
        ILidoWithdrawalQueue(0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1);

    PufferVault pufferVault;
    PufferVault pufferVaultImplementation;

    PufferDepositor pufferDepositor;
    PufferDepositor pufferDepositorImplementation;
    PufferOracle pufferOracle;

    ERC1967Proxy depositorProxy;
    ERC1967Proxy vaultProxy;

    AccessManager accessManager;

    address stETHAddress;

    function run() public broadcast returns (PufferDeployment memory) {
        string memory obj = "";

        accessManager = new AccessManager(_broadcaster);

        bytes32 pufferDepositorVault = bytes32("pufferDepositor");
        bytes32 pufferVaultSalt = bytes32("pufferVault");

        // UUPS proxy for PufferDepositor
        depositorProxy = new ERC1967Proxy{ salt: pufferDepositorVault }(address(new NoImplementation()), "");
        vm.label(address(depositorProxy), "PufferDepositor");

        // UUPS proxy for PufferVault
        vaultProxy = new ERC1967Proxy{ salt: pufferVaultSalt }(address(new NoImplementation()), "");
        vm.label(address(vaultProxy), "PufferVault");

        // Deploy mock Puffer oracle
        pufferOracle = new PufferOracle();

        {
            (
                IStETH stETHMock,
                ILidoWithdrawalQueue lidoWithdrawalQueue,
                IStrategy stETHStrategy,
                IEigenLayer eigenStrategyManager
            ) = _getArgs();

            stETHAddress = address(stETHMock);

            // Deploy implementation contracts
            pufferVaultImplementation =
                new PufferVault(IStETH(stETHAddress), lidoWithdrawalQueue, stETHStrategy, eigenStrategyManager);
            vm.label(address(pufferVault), "PufferVaultImplementation");
            pufferDepositorImplementation =
                new PufferDepositor({ stETH: IStETH(stETHAddress), pufferVault: PufferVault(payable(vaultProxy)) });
            vm.label(address(pufferDepositorImplementation), "PufferDepositorImplementation");
        }

        // Initialize Depositor
        NoImplementation(payable(address(depositorProxy))).upgradeToAndCall(
            address(pufferDepositorImplementation), abi.encodeCall(PufferDepositor.initialize, (address(accessManager)))
        );
        // Initialize Vault
        NoImplementation(payable(address(vaultProxy))).upgradeToAndCall(
            address(pufferVaultImplementation), abi.encodeCall(PufferVault.initialize, (address(accessManager)))
        );

        vm.serializeAddress(obj, "PufferDepositor", address(depositorProxy));
        vm.serializeAddress(obj, "PufferDepositorImplementation", address(pufferDepositorImplementation));
        vm.serializeAddress(obj, "PufferVault", address(vaultProxy));
        vm.serializeAddress(obj, "PufferVaultImplementation", address(pufferVaultImplementation));
        vm.serializeAddress(obj, "PufferOracle", address(pufferOracle));

        string memory finalJson = vm.serializeString(obj, "", "");
        vm.writeJson(finalJson, "./output/puffer.json");

        return PufferDeployment({
            accessManager: address(accessManager),
            pufferDepositorImplementation: address(pufferDepositorImplementation),
            pufferDepositor: address(depositorProxy),
            pufferVault: address(vaultProxy),
            pufferVaultImplementation: address(pufferVaultImplementation),
            pufferOracle: address(pufferOracle),
            stETH: stETHAddress
        });
    }

    function _getArgs()
        internal
        returns (
            IStETH stETH,
            ILidoWithdrawalQueue lidoWithdrawalQueue,
            IStrategy stETHStrategy,
            IEigenLayer eigenStrategyManager
        )
    {
        if (isMainnet()) {
            stETH = _ST_ETH;
            lidoWithdrawalQueue = _LIDO_WITHDRAWAL_QUEUE;
            stETHStrategy = _EIGEN_STETH_STRATEGY;
            eigenStrategyManager = _EIGEN_STRATEGY_MANAGER;
        } else {
            stETH = IStETH(address(new StETHMockERC20()));
            lidoWithdrawalQueue = new LidoWithdrawalQueueMock();
            stETHStrategy = new stETHStrategyMock();
            eigenStrategyManager = new EigenLayerManagerMock();
        }
    }
}
