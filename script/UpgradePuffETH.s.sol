// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { BaseScript } from "script/BaseScript.s.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { PufferVault } from "src/PufferVault.sol";
import { PufferVaultMainnet } from "src/PufferVaultMainnet.sol";
import { IEigenLayer } from "src/interface/EigenLayer/IEigenLayer.sol";
import { IStrategy } from "src/interface/EigenLayer/IStrategy.sol";
import { IStETH } from "src/interface/Lido/IStETH.sol";
import { ILidoWithdrawalQueue } from "src/interface/Lido/ILidoWithdrawalQueue.sol";
import { stETHMock } from "test/mocks/stETHMock.sol";
import { LidoWithdrawalQueueMock } from "test/mocks/LidoWithdrawalQueueMock.sol";
import { stETHStrategyMock } from "test/mocks/stETHStrategyMock.sol";
import { EigenLayerManagerMock } from "test/mocks/EigenLayerManagerMock.sol";
import { UUPSUpgradeable } from "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IWETH } from "src/interface/Other/IWETH.sol";
import { WETH9 } from "test/mocks/WETH9.sol";
import { Initializable } from "openzeppelin/proxy/utils/Initializable.sol";

/**
 * @title UpgradePufETH
 * @author Puffer Finance
 * @notice Upgrades PufETH
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
 *         PK=${deployer_pk} forge script script/UpgradePuffETH.s.sol:UpgradePuffETH --sig 'run(address)' "VAULTADDRESS" -vvvv --rpc-url=... --broadcast
 */
contract UpgradePuffETH is BaseScript {
    /**
     * @dev Ethereum Mainnet addresses
     */
    IStrategy internal constant _EIGEN_STETH_STRATEGY = IStrategy(0x93c4b944D05dfe6df7645A86cd2206016c51564D);
    IEigenLayer internal constant _EIGEN_STRATEGY_MANAGER = IEigenLayer(0x858646372CC42E1A627fcE94aa7A7033e7CF075A);
    IStETH internal constant _ST_ETH = IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IWETH internal constant _WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    ILidoWithdrawalQueue internal constant _LIDO_WITHDRAWAL_QUEUE =
        ILidoWithdrawalQueue(0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1);

    function run(address pufferVault) public broadcast {
        (
            IStETH stETH,
            IWETH weth,
            ILidoWithdrawalQueue lidoWithdrawalQueue,
            IStrategy stETHStrategy,
            IEigenLayer eigenStrategyManager
        ) = _getArgs();

        PufferVaultMainnet newImplementation =
            new PufferVaultMainnet(stETH, weth, lidoWithdrawalQueue, stETHStrategy, eigenStrategyManager);

        vm.expectEmit(true, true, true, true);
        emit Initializable.Initialized(2);
        UUPSUpgradeable(pufferVault).upgradeToAndCall(
            address(newImplementation), abi.encodeCall(PufferVaultMainnet.initialize, ())
        );
    }

    function _getArgs()
        internal
        returns (
            IStETH stETH,
            IWETH weth,
            ILidoWithdrawalQueue lidoWithdrawalQueue,
            IStrategy stETHStrategy,
            IEigenLayer eigenStrategyManager
        )
    {
        if (isMainnet()) {
            stETH = _ST_ETH;
            weth = _WETH;
            lidoWithdrawalQueue = _LIDO_WITHDRAWAL_QUEUE;
            stETHStrategy = _EIGEN_STETH_STRATEGY;
            eigenStrategyManager = _EIGEN_STRATEGY_MANAGER;
        } else {
            stETH = IStETH(address(new stETHMock()));
            weth = new WETH9();
            lidoWithdrawalQueue = new LidoWithdrawalQueueMock();
            stETHStrategy = new stETHStrategyMock();
            eigenStrategyManager = new EigenLayerManagerMock();
        }
    }
}
