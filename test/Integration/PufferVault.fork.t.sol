// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { PufferDepositor } from "../../src/PufferDepositor.sol";
import { IStETH } from "../../src/interface/Lido/IStETH.sol";
import { IEigenLayer } from "src/interface/EigenLayer/IEigenLayer.sol";
import { stdStorage, StdStorage } from "forge-std/Test.sol";
import { PufferVault } from "src/PufferVault.sol";
import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";
import { IStETH } from "src/interface/Lido/IStETH.sol";
import { IEigenLayer } from "src/interface/EigenLayer/IEigenLayer.sol";
import { IStrategy } from "src/interface/EigenLayer/IStrategy.sol";
import { Timelock } from "src/Timelock.sol";

contract PufferMainnetTest is Test {
    /**
     * @dev Ethereum Mainnet addresses
     */
    IStrategy internal constant _EIGEN_STETH_STRATEGY = IStrategy(0x93c4b944D05dfe6df7645A86cd2206016c51564D);
    IEigenLayer internal constant _EIGEN_STRATEGY_MANAGER = IEigenLayer(0x858646372CC42E1A627fcE94aa7A7033e7CF075A);
    IStETH internal constant _ST_ETH = IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    PufferDepositor public pufferDepositor;
    PufferVault public pufferVault;
    AccessManager public accessManager;
    Timelock public timelock;

    address alice = makeAddr("alice");

    address COMMUNITY_MULTISIG;
    address OPERATIONS_MULTISIG;

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"));

        _setupContracts();
    }

    function _setupContracts() internal {
        pufferDepositor = PufferDepositor(payable(0x4aA799C5dfc01ee7d790e3bf1a7C2257CE1DcefF));
        pufferVault = PufferVault(payable(0xD9A442856C234a39a81a089C06451EBAa4306a72));
        accessManager = AccessManager(payable(0x8c1686069474410E6243425f4a10177a94EBEE11));
        timelock = Timelock(payable(0x3C28B7c7Ba1A1f55c9Ce66b263B33B204f2126eA));

        COMMUNITY_MULTISIG = timelock.COMMUNITY_MULTISIG();
        OPERATIONS_MULTISIG = timelock.OPERATIONS_MULTISIG();

        vm.label(COMMUNITY_MULTISIG, "COMMUNITY_MULTISIG");
        vm.label(OPERATIONS_MULTISIG, "OPERATIONS_MULTISIG");
        vm.label(address(_ST_ETH), "stETH");
        vm.label(address(_EIGEN_STETH_STRATEGY), "Eigen stETH strategy");
    }

    function test_el_stETH_deposit() public {
        uint256 exchangeRateBefore = pufferVault.previewDeposit(1 ether);

        vm.startPrank(OPERATIONS_MULTISIG);

        pufferVault.depositToEigenLayer(1000 ether);

        uint256 exchangeRateAfterDeposit = pufferVault.previewDeposit(1 ether);

        assertEq(exchangeRateBefore, exchangeRateAfterDeposit, "exchange rate must not change after the deposit to EL");
    }
}
