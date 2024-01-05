// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { ERC1967Proxy } from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { BaseScript } from "script/BaseScript.s.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";
import { UpgradeableBeacon } from "openzeppelin/proxy/beacon/UpgradeableBeacon.sol";
import { pufETH, IPuffETH } from "src/pufETH.sol";
import { LidoVault } from "src/LidoVault.sol";
import { NoImplementation } from "src/NoImplementation.sol";
import { IStETH } from "src/interface/IStETH.sol";
import { IEigenLayer } from "src/interface/IEigenLayer.sol";
import { PufferDeployment } from "src/structs/PufferDeployment.sol";

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
 *
 *         PK=${deployer_pk} forge script script/DeployPuffer.s.sol:DeployPuffer -vvvv --rpc-url=$EPHEMERY_RPC_URL --broadcast
 */
contract DeployPuffETH is BaseScript {
    IStETH stETH;
    IEigenLayer eigenStrategyManager;

    LidoVault lidoVault;
    pufETH pufETHToken;
    pufETH pufETHImplementation;
    ERC1967Proxy proxy;
    AccessManager accessManager;

    address eigenPodManager;
    address delayedWithdrawalRouter;
    address delegationManager;

    function run() public broadcast returns (PufferDeployment memory) {
        string memory obj = "";

        bytes32 pufETHSalt = bytes32("pufETHSalt");

        if (isMainnet()) {
            // Mainnet / Mainnet fork
            stETH = IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
            vm.label(address(stETH), "stETH");
            eigenStrategyManager = IEigenLayer(0x858646372CC42E1A627fcE94aa7A7033e7CF075A);
            vm.label(address(eigenStrategyManager), "eigenStrategyManager");
        } else if (isAnvil()) { }

        // UUPS proxy for PufferProtocol
        proxy = new ERC1967Proxy{ salt: pufETHSalt }(address(new NoImplementation()), "");
        vm.label(address(proxy), "pufETH");

        {
            lidoVault = new LidoVault();
            vm.label(address(lidoVault), "LidoVault");
            // Puffer Service implementation
            pufETHImplementation =
                new pufETH({ stETH: stETH, eigenStrategyManager: eigenStrategyManager, lidoVault: lidoVault });
        }

        NoImplementation(payable(address(proxy))).upgradeToAndCall(
            address(pufETHImplementation), abi.encodeCall(pufETH.initialize, ())
        );

        pufETHToken = pufETH(payable(address(proxy)));

        vm.serializeAddress(obj, "PufETHProxy", address(pufETHToken));
        vm.serializeAddress(obj, "PufETHImplementation", address(pufETHImplementation));
        vm.serializeAddress(obj, "LidoVault", address(pufETHToken));

        string memory finalJson = vm.serializeString(obj, "", "");
        vm.writeJson(finalJson, "./output/puffer.json");

        return PufferDeployment({
            pufETHImplementation: address(pufETHImplementation),
            pufETHToken: address(pufETHToken),
            LidoVault: address(lidoVault)
        });
    }
}
