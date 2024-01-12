// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "erc4626-tests/ERC4626.test.sol";
import { IStETH } from "src/interface/Lido/IStETH.sol";
import { IPufferVault } from "src/interface/IPufferVault.sol";
import { PufferDepositor } from "src/PufferDepositor.sol";
import { PufferOracle } from "src/PufferOracle.sol";
import { PufferVault } from "src/PufferVault.sol";
import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";
import { StETHMockERC20 } from "../mocks/stETHMock.sol";
import { PufferDeployment } from "src/structs/PufferDeployment.sol";
import { DeployPuffETH } from "script/DeployPuffETH.s.sol";

contract PufETHTest is ERC4626Test {
    PufferDepositor public pufferDepositor;
    PufferVault public pufferVault;
    AccessManager public accessManager;
    PufferOracle public pufferOracle;
    IStETH public stETH;

    address operationsMultisig = makeAddr("operations");
    address communityMultisig = makeAddr("community");

    function setUp() public override {
        PufferDeployment memory deployment = new DeployPuffETH().run();

        pufferDepositor = PufferDepositor(payable(deployment.pufferDepositor));
        pufferVault = PufferVault(payable(deployment.pufferVault));
        accessManager = AccessManager(payable(deployment.accessManager));
        pufferOracle = PufferOracle(payable(deployment.pufferOracle));
        stETH = IStETH(payable(deployment.stETH));

        _underlying_ = address(stETH);
        _vault_ = address(pufferVault);
        _delta_ = 0;
        _vaultMayBeEmpty = false;
        _unlimitedAmount = false;
    }

    function test_erc4626_interface() public {
        StETHMockERC20(address(stETH)).mint(address(this), 2000 ether);
        stETH.approve(address(pufferVault), type(uint256).max);

        // Deposit works
        assertEq(pufferVault.deposit(1000 ether, address(this)), 1000 ether, "deposit");
        assertEq(pufferVault.mint(1000 ether, address(this)), 1000 ether, "mint");

        // Getters work
        assertEq(pufferVault.asset(), address(stETH), "bad asset");
        assertEq(pufferVault.totalAssets(), stETH.balanceOf(address(pufferVault)), "bad assets");
        assertEq(pufferVault.convertToShares(1 ether), 1 ether, "bad conversion");
        assertEq(pufferVault.convertToAssets(1 ether), 1 ether, "bad conversion shares");
        assertEq(pufferVault.maxDeposit(address(5)), type(uint256).max, "bad max deposit");
        assertEq(pufferVault.previewDeposit(1 ether), 1 ether, "preview shares");
        assertEq(pufferVault.maxMint(address(5)), type(uint256).max, "max mint");
        assertEq(pufferVault.previewMint(1 ether), 1 ether, "preview mint");
        assertEq(pufferVault.previewWithdraw(1000 ether), 1000 ether, "preview withdraw");
        assertEq(pufferVault.maxRedeem(address(this)), 2000 ether, "maxRedeem");
        assertEq(pufferVault.previewRedeem(1000 ether), 1000 ether, "previewRedeem");

        // Withdrawals are disabled
        vm.expectRevert(IPufferVault.WithdrawalsAreDisabled.selector);
        pufferVault.withdraw(1000 ether, address(this), address(this));

        vm.expectRevert(IPufferVault.WithdrawalsAreDisabled.selector);
        pufferVault.redeem(1000 ether, address(this), address(this));
    }

    // All withdrawals are disabled, we override these tests to not revert
    function test_RT_deposit_redeem(Init memory init, uint256 assets) public override { }
    function test_RT_deposit_withdraw(Init memory init, uint256 assets) public override { }
    function test_RT_mint_redeem(Init memory init, uint256 shares) public override { }
    function test_RT_mint_withdraw(Init memory init, uint256 shares) public override { }
    function test_RT_redeem_deposit(Init memory init, uint256 shares) public override { }
    function test_RT_redeem_mint(Init memory init, uint256 shares) public override { }
    function test_RT_withdraw_deposit(Init memory init, uint256 assets) public override { }
    function test_RT_withdraw_mint(Init memory init, uint256 assets) public override { }
    function test_previewRedeem(Init memory init, uint256 shares) public override { }
    function test_previewWithdraw(Init memory init, uint256 assets) public override { }
    function test_redeem(Init memory init, uint256 shares, uint256 allowance) public override { }
    function test_withdraw(Init memory init, uint256 assets, uint256 allowance) public override { }
}
