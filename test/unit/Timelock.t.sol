// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { PufferDepositor } from "src/PufferDepositor.sol";
import { Timelock } from "src/Timelock.sol";
import { PufferOracle } from "src/PufferOracle.sol";
import { PufferVault } from "src/PufferVault.sol";
import { stETHMock } from "test/mocks/stETHMock.sol";
import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";
import { IAccessManaged } from "openzeppelin/access/manager/IAccessManaged.sol";
import { PufferDeployment } from "src/structs/PufferDeployment.sol";
import { DeployPuffETH } from "script/DeployPuffETH.s.sol";

contract PufETHTest is Test {
    PufferDepositor public pufferDepositor;
    PufferVault public pufferVault;
    AccessManager public accessManager;
    PufferOracle public pufferOracle;
    stETHMock public stETH;
    Timelock public timelock;

    address operationsMultisig = makeAddr("operations");
    address communityMultisig = makeAddr("community");
    address pauserMultisig = makeAddr("pauser");

    address alice = makeAddr("alice");

    function setUp() public {
        PufferDeployment memory deployment = new DeployPuffETH().run();

        pufferDepositor = PufferDepositor(payable(deployment.pufferDepositor));
        pufferVault = PufferVault(payable(deployment.pufferVault));
        accessManager = AccessManager(payable(deployment.accessManager));
        pufferOracle = PufferOracle(payable(deployment.pufferOracle));
        stETH = stETHMock(payable(deployment.stETH));
        timelock = Timelock(payable(deployment.timelock));
    }

    function test_pause() public {
        //@todo broken test,
        // stETH.mint(alice, 600 ether);

        // Set that `deposit` is a public function
        // vm.startPrank(timelock.COMMUNITY_MULTISIG());
        // bytes4[] memory selectors = new bytes4[](1);
        // selectors[0] = PufferDepositor.deposit.selector;
        // bytes memory callData = abi.encodeCall(
        //     AccessManager.setTargetFunctionRole, (address(pufferVault), selectors, accessManager.PUBLIC_ROLE())
        // );
        // timelock.executeTransaction(address(accessManager), callData);

        // Alice can deposit
        // vm.startPrank(alice);
        // stETH.approve(address(pufferVault), type(uint256).max);
        // pufferVault.deposit(300 ether, alice);

        // // Pauser calls pause
        // vm.startPrank(pauserMultisig);
        // address[] memory targets = new address[](1);
        // targets[0] = address(pufferVault);
        // timelock.pause(targets);

        // // Alice cant deposit again
        // vm.startPrank(alice);
        // vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, alice));
        // pufferVault.deposit(300 ether, alice);
    }
}
