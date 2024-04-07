// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { stdJson } from "forge-std/StdJson.sol";
import { BaseScript } from ".//BaseScript.s.sol";
import { PufferVault } from "../src/PufferVault.sol";
import { PufferVaultV2 } from "../src/PufferVaultV2.sol";
import { PufferVaultV2Tests } from "../src/PufferVaultV2Tests.sol";
import { IEigenLayer } from "../src/interface/EigenLayer/IEigenLayer.sol";
import { IStrategy } from "../src/interface/EigenLayer/IStrategy.sol";
import { IDelegationManager } from "../src/interface/EigenLayer/IDelegationManager.sol";
import { IStETH } from "../src/interface/Lido/IStETH.sol";
import { ILidoWithdrawalQueue } from "../src/interface/Lido/ILidoWithdrawalQueue.sol";
import { LidoWithdrawalQueueMock } from "../test/mocks/LidoWithdrawalQueueMock.sol";
import { stETHStrategyMock } from "../test/mocks/stETHStrategyMock.sol";
import { UUPSUpgradeable } from "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { IWETH } from "../src/interface/Other/IWETH.sol";
import { IPufferOracle } from "../src/interface/IPufferOracle.sol";
import { Initializable } from "openzeppelin/proxy/utils/Initializable.sol";
import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";
import { PufferDeployment } from "../src/structs/PufferDeployment.sol";

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
 *         PK=${deployer_pk} forge script script/UpgradePufETH.s.sol:UpgradePufETH --sig 'run(address)' "VAULTADDRESS" -vvvv --rpc-url=... --broadcast
 */
contract UpgradePufETH is BaseScript {
    /**
     * @dev Ethereum Mainnet addresses
     */
    IStrategy internal constant _EIGEN_STETH_STRATEGY = IStrategy(0x93c4b944D05dfe6df7645A86cd2206016c51564D);
    IEigenLayer internal constant _EIGEN_STRATEGY_MANAGER = IEigenLayer(0x858646372CC42E1A627fcE94aa7A7033e7CF075A);
    IDelegationManager internal constant _DELEGATION_MANAGER =
        IDelegationManager(0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A);
    IStETH internal constant _ST_ETH = IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IWETH internal constant _WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    ILidoWithdrawalQueue internal constant _LIDO_WITHDRAWAL_QUEUE =
        ILidoWithdrawalQueue(0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1);

    function run(PufferDeployment memory deployment, address pufferOracle) public broadcast {
        //@todo this is for tests only
        AccessManager(deployment.accessManager).grantRole(1, _broadcaster, 0);

        PufferVaultV2 newImplementation = new PufferVaultV2Tests(
            IStETH(deployment.stETH),
            IWETH(deployment.weth),
            ILidoWithdrawalQueue(deployment.lidoWithdrawalQueueMock),
            IStrategy(deployment.stETHStrategyMock),
            IEigenLayer(deployment.eigenStrategyManagerMock),
            IPufferOracle(pufferOracle),
            _DELEGATION_MANAGER
        );

        vm.expectEmit(true, true, true, true);
        emit Initializable.Initialized(2);
        UUPSUpgradeable(deployment.pufferVault).upgradeToAndCall(
            address(newImplementation), abi.encodeCall(PufferVaultV2.initialize, ())
        );
    }
}
