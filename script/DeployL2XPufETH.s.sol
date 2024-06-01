// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { BaseScript } from ".//BaseScript.s.sol";
import { xPufETH } from "../src/l2/xPufETH.sol";
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

    address _CONNEXT = 0x8247ed6d0a344eeae4edBC7e44572F1B70ECA82A; //@todo change for mainnet
    uint256 _MINTING_LIMIT = 1000 * 1e18; //@todo
    uint256 _BURNING_LIMIT = 1000 * 1e18; //@todo

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

        console.log("Timelock", address(timelock));

        xPufETH newImplementation = new xPufETH();
        console.log("XERC20PufferVaultImplementation", address(newImplementation));

        bytes32 xPufETHSalt = bytes32("xPufETH");

        vm.expectEmit(true, true, true, true);
        emit Initializable.Initialized(1);
        ERC1967Proxy xPufETHProxy = new ERC1967Proxy{ salt: xPufETHSalt }(
            address(newImplementation), abi.encodeCall(xPufETH.initialize, (address(accessManager)))
        );
        console.log("xPufETHProxy", address(xPufETHProxy));

        bytes memory data = abi.encodeWithSelector(xPufETH.setLimits.selector, _CONNEXT, _MINTING_LIMIT, _BURNING_LIMIT);

        accessManager.execute(address(xPufETHProxy), data);

        bytes4[] memory daoSelectors = new bytes4[](2);
        daoSelectors[0] = xPufETH.setLockbox.selector;
        daoSelectors[1] = xPufETH.setLimits.selector;

        bytes4[] memory publicSelectors = new bytes4[](2);
        publicSelectors[0] = xPufETH.mint.selector;
        publicSelectors[1] = xPufETH.burn.selector;

        // Setup Access
        // Public selectors
        accessManager.setTargetFunctionRole(address(xPufETHProxy), publicSelectors, accessManager.PUBLIC_ROLE());
        // Dao selectors
        accessManager.setTargetFunctionRole(address(xPufETHProxy), daoSelectors, ROLE_ID_DAO);

        accessManager.grantRole(accessManager.ADMIN_ROLE(), address(timelock), 0);

        //@todo replace with dao and ops multisigs for mainnet
        accessManager.grantRole(ROLE_ID_DAO, _broadcaster, 0);
        accessManager.grantRole(ROLE_ID_OPERATIONS_MULTISIG, _broadcaster, 0);

        //@todo revoke on mainnet
        // accessManager.revokeRole(accessManager.ADMIN_ROLE(), _broadcaster);
    }
}
