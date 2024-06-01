// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { PufferDepositor } from "src/PufferDepositor.sol";
import { Timelock } from "src/Timelock.sol";
import { PufferVault } from "src/PufferVault.sol";
import { xPufETH } from "src/l2/xPufETH.sol";
import { XERC20Lockbox } from "src/XERC20Lockbox.sol";
import { stETHMock } from "test/mocks/stETHMock.sol";
import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";
import { PufferDeployment } from "src/structs/PufferDeployment.sol";
import { DeployPufETH } from "script/DeployPufETH.s.sol";
import { ROLE_ID_DAO, ROLE_ID_LOCKBOX } from "script/Roles.sol";
import { ERC1967Proxy } from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { Initializable } from "openzeppelin/proxy/utils/Initializable.sol";

contract xPufETHTest is Test {
    PufferDepositor public pufferDepositor;
    PufferVault public pufferVault;
    AccessManager public accessManager;
    stETHMock public stETH;
    Timelock public timelock;
    xPufETH public xPufETHProxy;
    XERC20Lockbox public xERC20Lockbox;

    function setUp() public {
        PufferDeployment memory deployment = new DeployPufETH().run();
        pufferDepositor = PufferDepositor(payable(deployment.pufferDepositor));
        pufferVault = PufferVault(payable(deployment.pufferVault));
        accessManager = AccessManager(payable(deployment.accessManager));
        stETH = stETHMock(payable(deployment.stETH));
        timelock = Timelock(payable(deployment.timelock));

        // Deploy implementation
        xPufETH newImplementation = new xPufETH();

        // Deploy proxy
        vm.expectEmit(true, true, true, true);
        emit Initializable.Initialized(1);
        xPufETHProxy = xPufETH(
            address(
                new ERC1967Proxy{ salt: bytes32("xPufETH") }(
                    address(newImplementation), abi.encodeCall(xPufETH.initialize, (address(accessManager)))
                )
            )
        );

        // Deploy the lockbox
        xERC20Lockbox = new XERC20Lockbox(address(xPufETHProxy), address(deployment.pufferVault));

        // Setup AccessManager stuff
        // Setup access
        bytes4[] memory daoSelectors = new bytes4[](2);
        daoSelectors[0] = xPufETH.setLockbox.selector;
        daoSelectors[1] = xPufETH.setLimits.selector;

        bytes4[] memory lockBoxSelectors = new bytes4[](2);
        lockBoxSelectors[0] = xPufETH.mint.selector;
        lockBoxSelectors[1] = xPufETH.burn.selector;

        // Public selectors
        vm.startPrank(address(timelock));
        accessManager.setTargetFunctionRole(address(xPufETHProxy), lockBoxSelectors, accessManager.PUBLIC_ROLE());
        accessManager.setTargetFunctionRole(address(xPufETHProxy), daoSelectors, ROLE_ID_DAO);
        accessManager.grantRole(ROLE_ID_LOCKBOX, address(xERC20Lockbox), 0);
        accessManager.grantRole(ROLE_ID_DAO, address(this), 0); // this contract is the dao for simplicity
        vm.stopPrank();

        // Set the Lockbox)
        xPufETHProxy.setLockbox(address(xERC20Lockbox));

        // Mint mock steth to this contract
        stETH.mint(address(this), type(uint128).max);
    }

    // We deposit pufETH to get xpufETH to this contract using .depositTo
    function test_mint_xpufETH(uint8 amount) public {
        stETH.approve(address(pufferVault), type(uint256).max);
        pufferVault.deposit(uint256(amount), address(this));

        pufferVault.approve(address(xERC20Lockbox), type(uint256).max);
        xERC20Lockbox.depositTo(address(this), uint256(amount));
        assertEq(xPufETHProxy.balanceOf(address(this)), uint256(amount), "got xpufETH");
        assertEq(pufferVault.balanceOf(address(xERC20Lockbox)), uint256(amount), "pufETH is in the lockbox");
    }

    // We deposit pufETH to get xpufETH to this contract using .deposit
    function test_deposit_pufETH_for_xpufETH(uint8 amount) public {
        stETH.approve(address(pufferVault), type(uint256).max);
        pufferVault.deposit(uint256(amount), address(this));

        pufferVault.approve(address(xERC20Lockbox), type(uint256).max);
        xERC20Lockbox.deposit(uint256(amount));
        assertEq(xPufETHProxy.balanceOf(address(this)), uint256(amount), "got xpufETH");
        assertEq(pufferVault.balanceOf(address(xERC20Lockbox)), uint256(amount), "pufETH is in the lockbox");
    }

    // We withdraw pufETH to Bob
    function test_mint_and_burn_xpufETH(uint8 amount) public {
        address bob = makeAddr("bob");
        test_mint_xpufETH(amount);

        xPufETHProxy.approve(address(xERC20Lockbox), type(uint256).max);
        xERC20Lockbox.withdrawTo(bob, uint256(amount));
        assertEq(pufferVault.balanceOf(bob), amount, "bob got pufETH");
    }

    // We withdraw to self
    function test_mint_and_withdraw_xpufETH(uint8 amount) public {
        test_mint_xpufETH(amount);

        xPufETHProxy.approve(address(xERC20Lockbox), type(uint256).max);

        uint256 pufEThBalanceBefore = pufferVault.balanceOf(address(this));

        xERC20Lockbox.withdraw(uint256(amount));
        assertEq(pufferVault.balanceOf(address(this)), pufEThBalanceBefore + amount, "we got pufETH");
    }

    function test_nativeReverts() public {
        vm.expectRevert();
        xERC20Lockbox.depositNativeTo(address(0));

        vm.expectRevert();
        xERC20Lockbox.depositNative();
    }
}
