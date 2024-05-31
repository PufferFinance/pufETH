// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { BaseScript } from ".//BaseScript.s.sol";
import { XERC20PufferVault } from "../src/l2/XERC20PufferVault.sol";
import { UUPSUpgradeable } from "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "openzeppelin/proxy/utils/Initializable.sol";
import { Timelock } from "../src/Timelock.sol";
import { ERC1967Proxy } from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";
import { ROLE_ID_DAO, ROLE_ID_OPERATIONS_MULTISIG } from "./Roles.sol";

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
 *         PK=a990c824d7f6928806d93674ef4acd4b240ad60c9ce575777c87b36f9a3c32a8 forge script script/DeployL2XPufETH.s.sol:DeployL2XPufETH -vvvv --rpc-url=https://holesky.gateway.tenderly.co/5ovlGAOeSvuI3UcQD2PoSD --broadcast
 */
contract DeployL2XPufETH is BaseScript {
    address operationsMultisig = vm.envOr("OPERATIONS_MULTISIG", makeAddr("operationsMultisig"));
    address pauserMultisig = vm.envOr("PAUSER_MULTISIG", makeAddr("pauserMultisig"));
    address communityMultisig = vm.envOr("COMMUNITY_MULTISIG", makeAddr("communityMultisig"));

    address _CONNEXT = 0x8247ed6d0a344eeae4edBC7e44572F1B70ECA82A; // change for mainnet
    uint256 _MINTING_LIMIT = 1000 * 1e18;
    uint256 _BURNING_LIMIT = 1000 * 1e18;

    function run() public broadcast {
        AccessManager accessManager = new AccessManager(_broadcaster);

        console.log("AccessManager", address(accessManager));

        operationsMultisig = _broadcaster;
        pauserMultisig = _broadcaster;
        communityMultisig = _broadcaster;

        Timelock timelock = new Timelock({
            accessManager: address(accessManager),
            communityMultisig: communityMultisig,
            operationsMultisig: operationsMultisig,
            pauser: pauserMultisig,
            initialDelay: 7 days
        });

        console.log("AccessManager", address(timelock));

        XERC20PufferVault newImplementation = new XERC20PufferVault();
        console.log("XERC20PufferVault", address(newImplementation));

        bytes32 xPufETHSalt = bytes32("xPufETH");

        ERC1967Proxy xPufETH = new ERC1967Proxy{ salt: xPufETHSalt }(
            address(newImplementation), abi.encodeCall(XERC20PufferVault.initialize, (address(accessManager)))
        );
        console.log("xPufETHProxy", address(xPufETH));

        vm.expectEmit(true, true, true, true);
        emit Initializable.Initialized(1);

        bytes memory data =
            abi.encodeWithSelector(XERC20PufferVault.setLimits.selector, _CONNEXT, _MINTING_LIMIT, _BURNING_LIMIT);

        accessManager.execute(address(xPufETH), data);

        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = XERC20PufferVault.setLockbox.selector;
        selectors[1] = XERC20PufferVault.setLimits.selector;

        // Setup Access
        accessManager.setTargetFunctionRole(address(xPufETH), selectors, ROLE_ID_DAO);

        accessManager.grantRole(accessManager.ADMIN_ROLE(), address(timelock), 0);

        // replace with dao and ops multisigs for mainnet
        accessManager.grantRole(ROLE_ID_DAO, _broadcaster, 0);
        accessManager.grantRole(ROLE_ID_OPERATIONS_MULTISIG, _broadcaster, 0);

        // revoke on mainnet
        // accessManager.revokeRole(accessManager.ADMIN_ROLE(), _broadcaster);
    }
}
