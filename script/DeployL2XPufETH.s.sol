// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { stdJson } from "forge-std/StdJson.sol";
import { BaseScript } from ".//BaseScript.s.sol";
import { XERC20PufferVault } from "../src/l2/XERC20PufferVault.sol";
import { UUPSUpgradeable } from "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "openzeppelin/proxy/utils/Initializable.sol";
import { NoImplementation } from "../src/NoImplementation.sol";
import { Timelock } from "../src/Timelock.sol";
import { ERC1967Proxy } from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";

/**
 * @title DeployL2XPufETH
 * @author Puffer Finance
 * @notice Deploy XPufETH
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
 *         PK=${deployer_pk} forge script script/DeployL2XPufETH.s.sol:DeployL2XPufETH -vvvv --rpc-url=... --broadcast
 */
contract DeployL2XPufETH is BaseScript {
    address operationsMultisig = vm.envOr("OPERATIONS_MULTISIG", makeAddr("operationsMultisig"));
    address pauserMultisig = vm.envOr("PAUSER_MULTISIG", makeAddr("pauserMultisig"));
    address communityMultisig = vm.envOr("COMMUNITY_MULTISIG", makeAddr("communityMultisig"));

    function run() public broadcast {
        AccessManager accessManager = new AccessManager(_broadcaster);

        Timelock timelock = new Timelock({
            accessManager: address(accessManager),
            communityMultisig: communityMultisig,
            operationsMultisig: operationsMultisig,
            pauser: pauserMultisig,
            initialDelay: 7 days + 1
        });

        address noImpl = address(new NoImplementation());

        bytes32 xPufETHSalt = bytes32("xPufETH");

        ERC1967Proxy xPufETH = new ERC1967Proxy{ salt: xPufETHSalt }(noImpl, "");
        vm.label(address(xPufETH), "xPufETH");

        XERC20PufferVault newImplementation = new XERC20PufferVault();

        vm.expectEmit(true, true, true, true);
        emit Initializable.Initialized(1);
        NoImplementation(payable(address(xPufETH))).upgradeToAndCall(
            address(newImplementation), abi.encodeCall(XERC20PufferVault.initialize, (address(accessManager)))
        );
    }
}
