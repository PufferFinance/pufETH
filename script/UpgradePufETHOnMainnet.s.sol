// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";
import { PufferDepositorV2 } from "../src/PufferDepositorV2.sol";
import { PufferVaultV2 } from "../src/PufferVaultV2.sol";
import { IEigenLayer } from "../src/interface/EigenLayer/IEigenLayer.sol";
import { IStrategy } from "../src/interface/EigenLayer/IStrategy.sol";
import { IDelegationManager } from "../src/interface/EigenLayer/IDelegationManager.sol";
import { IStETH } from "../src/interface/Lido/IStETH.sol";
import { ILidoWithdrawalQueue } from "../src/interface/Lido/ILidoWithdrawalQueue.sol";
import { IWETH } from "../src/interface/Other/IWETH.sol";
import { IPufferOracle } from "../src/interface/IPufferOracle.sol";

/**
 * @title UpgradePufETHOnMainnet
 * @author Puffer Finance
 * @notice Deploys PufferPoolV2 and Contracts
 * @dev
 *
 *         forge script script/UpgradePufETHOnMainnet.s.sol:UpgradePufETHOnMainnet -vvvv --private-key=... --rpc-url=... --broadcast --slow
 */
contract UpgradePufETHOnMainnet is Script {
    // Puffer
    address PUFFER_VAULT_PROXY = 0xD9A442856C234a39a81a089C06451EBAa4306a72;
    address PUFFER_DEPOSITOR_PROXY = 0x4aA799C5dfc01ee7d790e3bf1a7C2257CE1DcefF;

    IPufferOracle PUFFER_ORACLE = IPufferOracle(0x8eFd1Dc43AD073232F3e2924e22F173879119489);
    AccessManager ACCESS_MANAGER = AccessManager(0x8c1686069474410E6243425f4a10177a94EBEE11);

    // WETH
    IWETH WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // Lido
    IStETH ST_ETH = IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    ILidoWithdrawalQueue LIDO_WITHDRAWAL_QUEUE = ILidoWithdrawalQueue(0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1);

    // EigenLayer
    IDelegationManager DELEGATION_MANAGER = IDelegationManager(0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A);
    IStrategy STETH_STRATEGY = IStrategy(0x93c4b944D05dfe6df7645A86cd2206016c51564D);
    IEigenLayer EIGEN_STRATEGY_MANAGER = IEigenLayer(0x858646372CC42E1A627fcE94aa7A7033e7CF075A);

    function run() public {
        vm.startBroadcast();
        // Deploy implementation contracts
        PufferVaultV2 pufferVaultImplementation = new PufferVaultV2({
            stETH: ST_ETH,
            weth: WETH,
            lidoWithdrawalQueue: LIDO_WITHDRAWAL_QUEUE,
            stETHStrategy: STETH_STRATEGY,
            eigenStrategyManager: EIGEN_STRATEGY_MANAGER,
            oracle: PUFFER_ORACLE,
            delegationManager: DELEGATION_MANAGER
        });
        vm.label(address(pufferVaultImplementation), "PufferVaultImplementation");

        PufferDepositorV2 pufferDepositorImplementation =
            new PufferDepositorV2({ stETH: ST_ETH, pufferVault: PufferVaultV2(payable(PUFFER_VAULT_PROXY)) });

        vm.label(address(pufferDepositorImplementation), "PufferDepositorImplementation");
    }
}
