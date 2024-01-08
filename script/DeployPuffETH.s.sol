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
import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";

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
    PufferVault pufferVault;
    PufferVault pufferVaultImplementation;

    PufferDepositor pufferDepositor;
    PufferDepositor pufferDepositorImplementation;
    PufferOracle pufferOracle;

    ERC1967Proxy depositorProxy;
    ERC1967Proxy vaultProxy;

    AccessManager accessManager;

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
            // Deploy implementation contracts
            pufferVaultImplementation = new PufferVault();
            vm.label(address(pufferVault), "PufferVaultImplementation");
            pufferDepositorImplementation = new PufferDepositor({ pufferVault: PufferVault(payable(vaultProxy)) });
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
            pufferOracle: address(pufferOracle)
        });
    }
}
