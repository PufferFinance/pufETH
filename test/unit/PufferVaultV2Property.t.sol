// SPDX-License-Identifier: AGPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "erc4626-tests/ERC4626.test.sol";
import { IStETH } from "../../src/interface/Lido/IStETH.sol";
import { PufferDepositor } from "../../src/PufferDepositor.sol";
import { PufferVault } from "../../src/PufferVault.sol";
import { PufferVaultV2 } from "../../src/PufferVaultV2.sol";
import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";
import { PufferDeployment } from "../../src/structs/PufferDeployment.sol";
import { DeployPufETH } from "script/DeployPufETH.s.sol";
import { UpgradePufETH } from "script/UpgradePufETH.s.sol";
import { MockPufferOracle } from "../mocks/MockPufferOracle.sol";
import { WETH9 } from "../mocks/WETH9.sol";
import { ROLE_ID_DAO } from "../../script/Roles.sol";
import { GenerateAccessManagerCallData } from "script/GenerateAccessManagerCallData.sol";

contract PufferVaultV2Property is ERC4626Test {
    PufferDepositor public pufferDepositor;
    PufferVaultV2 public pufferVault;
    AccessManager public accessManager;
    IStETH public stETH;
    WETH9 public weth;

    function setUp() public override {
        PufferDeployment memory deployment = new DeployPufETH().run();

        MockPufferOracle mockOracle = new MockPufferOracle();

        new UpgradePufETH().run(deployment, address(mockOracle));

        pufferDepositor = PufferDepositor(payable(deployment.pufferDepositor));
        pufferVault = PufferVaultV2(payable(deployment.pufferVault));
        accessManager = AccessManager(payable(deployment.accessManager));
        stETH = IStETH(payable(deployment.stETH));

        // vm.prank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        // accessManager.grantRole(ROLE_ID_DAO, 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266, 0);
        // vm.prank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        // pufferVault.setDailyWithdrawalLimit(type(uint96).max);

        // Setup access for public
        bytes memory encodedMulticall =
            new GenerateAccessManagerCallData().run(address(pufferVault), address(pufferDepositor), address(5));

        vm.prank(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);
        (bool s,) = address(accessManager).call(encodedMulticall);
        require(s, "success");

        weth = WETH9(payable(deployment.weth));

        _underlying_ = address(deployment.weth);
        _vault_ = address(pufferVault);
        _delta_ = 0;
        _vaultMayBeEmpty = false;
        _unlimitedAmount = false;
    }

    // In test/Integration/PufferVaultV2.fork.t.sol we test that ETH and WETH and STETH deposits should give you the same amount of shares
    // in `test_eth_weth_stETH_deposits`
}
