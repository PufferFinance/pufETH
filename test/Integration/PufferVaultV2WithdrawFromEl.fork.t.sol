// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { PufferVaultV2 } from "../../src/PufferVaultV2.sol";
import { IStETH } from "../../src/interface/Lido/IStETH.sol";
import { ILidoWithdrawalQueue } from "../../src/interface/Lido/ILidoWithdrawalQueue.sol";
import { IWETH } from "../../src/interface/Other/IWETH.sol";
import { IStrategy } from "../../src/interface/EigenLayer/IStrategy.sol";
import { IEigenLayer } from "../../src/interface/EigenLayer/IEigenLayer.sol";
import { IDelegationManager } from "../../src/interface/EigenLayer/IDelegationManager.sol";
import { UUPSUpgradeable } from "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IPufferOracle } from "../../src/interface/IPufferOracle.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";
import { ERC1967Utils } from "openzeppelin/proxy/ERC1967/ERC1967Utils.sol";
import { ROLE_ID_OPERATIONS_MULTISIG } from "../../script/Roles.sol";

contract PufferVaultWithdrawalTest is Test {
    address pufferVault = 0xa4321158b2F447Aa54f3422E5Cbaa54C85B82CfC;

    PufferVaultV2 newImpl;

    function setUp() public {
        // Cancun upgrade
        vm.createSelectFork(vm.rpcUrl("holesky"), 1299782);

        IStETH stETH = IStETH(address(0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034));
        IWETH weth = IWETH(0xD6eF375Ad62f1d5BC06479fD0c7DCEF28e5Dc898);
        ILidoWithdrawalQueue lidoWithdrawalQueue = ILidoWithdrawalQueue(0xc7cc160b58F8Bb0baC94b80847E2CF2800565C50);
        IStrategy stETHStrategy = IStrategy(0x7D704507b76571a51d9caE8AdDAbBFd0ba0e63d3);
        IEigenLayer eigenStrategyManager = IEigenLayer(0xdfB5f6CE42aAA7830E94ECFCcAd411beF4d4D5b6);
        IPufferOracle oracle = IPufferOracle(address(0)); // not needed for this test
        IDelegationManager delegationManager = IDelegationManager(0xA44151489861Fe9e3055d95adC98FbD462B948e7);

        newImpl = new PufferVaultV2(
            stETH, weth, lidoWithdrawalQueue, stETHStrategy, eigenStrategyManager, oracle, delegationManager
        );
    }

    function test_m2_el_withdrawal() public {
        // Community multisig
        vm.startPrank(0xf9F846FA49e79BE8d74c68CDC01AaaFfBBf8177F);

        vm.expectEmit(true, true, true, true);
        emit ERC1967Utils.Upgraded(address(newImpl));
        UUPSUpgradeable(pufferVault).upgradeToAndCall(address(newImpl), abi.encodeCall(PufferVaultV2.initialize, ()));

        // Operations multisig
        vm.startPrank(0x5568b309259131D3A7c128700195e0A1C94761A0);
        PufferVaultV2(payable(pufferVault)).initiateStETHWithdrawalFromEigenLayer(0.01 ether);

        uint256 startBlock = block.number;

        vm.roll(block.number + 10000);

        IEigenLayer.WithdrawerAndNonce memory withdrawerAndNonce =
            IEigenLayer.WithdrawerAndNonce({ withdrawer: address(pufferVault), nonce: 0 });

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(address(0x3F1c547b21f65e10480dE3ad8E19fAAC46C95034)); // stETH

        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = IStrategy(0x7D704507b76571a51d9caE8AdDAbBFd0ba0e63d3);

        uint256[] memory shares = new uint256[](1);
        shares[0] = 0.01 ether;

        IEigenLayer.QueuedWithdrawal memory queuedWithdrawal = IEigenLayer.QueuedWithdrawal({
            strategies: strategies,
            shares: shares,
            depositor: address(pufferVault),
            withdrawerAndNonce: withdrawerAndNonce,
            withdrawalStartBlock: uint32(startBlock),
            delegatedAddress: address(0)
        });

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = PufferVaultV2.claimWithdrawalFromEigenLayerM2.selector;

        vm.startPrank(0xDDDeAfB492752FC64220ddB3E7C9f1d5CcCdFdF0);
        AccessManager(0xdD47507B8f3134bcBf04D77ac96BA46404cBde16).setTargetFunctionRole(
            pufferVault, selectors, ROLE_ID_OPERATIONS_MULTISIG
        );

        // Operations multisig
        vm.startPrank(0x5568b309259131D3A7c128700195e0A1C94761A0);
        PufferVaultV2(payable(pufferVault)).claimWithdrawalFromEigenLayerM2(queuedWithdrawal, tokens, 0, 0);
    }
}
