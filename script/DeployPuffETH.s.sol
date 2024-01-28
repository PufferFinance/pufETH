// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { ERC1967Proxy } from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";
import { BaseScript } from "script/BaseScript.s.sol";
import { stdJson } from "forge-std/StdJson.sol";
import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";
import { PufferDepositor } from "src/PufferDepositor.sol";
import { PufferOracle } from "src/PufferOracle.sol";
import { PufferVault } from "src/PufferVault.sol";
import { Timelock } from "src/Timelock.sol";
import { NoImplementation } from "src/NoImplementation.sol";
import { PufferDeployment } from "src/structs/PufferDeployment.sol";
import { IEigenLayer } from "src/interface/EigenLayer/IEigenLayer.sol";
import { IStrategy } from "src/interface/EigenLayer/IStrategy.sol";
import { IStETH } from "src/interface/Lido/IStETH.sol";
import { ILidoWithdrawalQueue } from "src/interface/Lido/ILidoWithdrawalQueue.sol";
import { stETHMock } from "test/mocks/stETHMock.sol";
import { LidoWithdrawalQueueMock } from "test/mocks/LidoWithdrawalQueueMock.sol";
import { stETHStrategyMock } from "test/mocks/stETHStrategyMock.sol";
import { EigenLayerManagerMock } from "test/mocks/EigenLayerManagerMock.sol";
import { UUPSUpgradeable } from "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title DeployPuffer
 * @author Puffer Finance
 * @notice Deploys PufferPool Contracts
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
 *         PK=${deployer_pk} forge script script/DeployPuffETH.s.sol:DeployPuffETH -vvvv --rpc-url=... --broadcast
 */
contract DeployPuffETH is BaseScript {
    uint64 constant ROLE_ID_UPGRADER = 1;
    uint64 constant ROLE_ID_OPERATIONS = 22;

    /**
     * @dev Ethereum Mainnet addresses
     */
    IStrategy internal constant _EIGEN_STETH_STRATEGY = IStrategy(0x93c4b944D05dfe6df7645A86cd2206016c51564D);
    IEigenLayer internal constant _EIGEN_STRATEGY_MANAGER = IEigenLayer(0x858646372CC42E1A627fcE94aa7A7033e7CF075A);
    IStETH internal constant _ST_ETH = IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    ILidoWithdrawalQueue internal constant _LIDO_WITHDRAWAL_QUEUE =
        ILidoWithdrawalQueue(0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1);

    PufferVault pufferVault;
    PufferVault pufferVaultImplementation;

    PufferDepositor pufferDepositor;
    PufferDepositor pufferDepositorImplementation;
    PufferOracle pufferOracle;
    Timelock timelock;

    ERC1967Proxy depositorProxy;
    ERC1967Proxy vaultProxy;

    AccessManager accessManager;

    address stETHAddress;

    address operationsMultisig = vm.envOr("OPERATIONS_MULTISIG", makeAddr("operationsMultisig"));
    address pauserMultisig = vm.envOr("PAUSER_MULTISIG", makeAddr("pauserMultisig"));
    address communityMultisig = vm.envOr("COMMUNITY_MULTISIG", makeAddr("communityMultisig"));

    function run() public broadcast returns (PufferDeployment memory) {
        string memory obj = "";

        accessManager = new AccessManager(_broadcaster);

        bytes32 pufferDepositorVault = bytes32("pufferDepositor");
        bytes32 pufferVaultSalt = bytes32("pufferVault");

        // UUPS proxy for PufferDepositor
        depositorProxy = new ERC1967Proxy{ salt: pufferDepositorVault }(address(new NoImplementation()), "");
        vm.label(address(depositorProxy), "PufferDepositor");

        // UUPS proxy for PufferVault
        vaultProxy = new ERC1967Proxy{ salt: pufferVaultSalt }(address(new NoImplementation()), "");
        vm.label(address(vaultProxy), "PufferVault");

        // Deploy mock Puffer oracle
        pufferOracle = new PufferOracle();
        timelock = new Timelock({
            accessManager: address(accessManager),
            communityMultisig: communityMultisig,
            operationsMultisig: operationsMultisig,
            pauser: pauserMultisig,
            initialDelay: 7 days
        });

        {
            (
                IStETH stETH,
                ILidoWithdrawalQueue lidoWithdrawalQueue,
                IStrategy stETHStrategy,
                IEigenLayer eigenStrategyManager
            ) = _getArgs();

            stETHAddress = address(stETH);

            // Deploy implementation contracts
            pufferVaultImplementation =
                new PufferVault(IStETH(stETHAddress), lidoWithdrawalQueue, stETHStrategy, eigenStrategyManager);
            vm.label(address(pufferVaultImplementation), "PufferVaultImplementation");
            pufferDepositorImplementation =
                new PufferDepositor({ stETH: IStETH(stETHAddress), pufferVault: PufferVault(payable(vaultProxy)) });
            vm.label(address(pufferDepositorImplementation), "PufferDepositorImplementation");
        }

        // Initialize Depositor
        NoImplementation(payable(address(depositorProxy))).upgradeToAndCall(
            address(pufferDepositorImplementation), abi.encodeCall(PufferDepositor.initialize, (address(accessManager)))
        );
        // Initialize Vault
        NoImplementation(payable(address(vaultProxy))).upgradeToAndCall(
            address(pufferVaultImplementation), abi.encodeCall(PufferVault.initialize, (address(accessManager)))
        );

        vm.serializeAddress(obj, "PufferDepositor", address(depositorProxy));
        vm.serializeAddress(obj, "PufferDepositorImplementation", address(pufferDepositorImplementation));
        vm.serializeAddress(obj, "PufferVault", address(vaultProxy));
        vm.serializeAddress(obj, "PufferVaultImplementation", address(pufferVaultImplementation));
        vm.serializeAddress(obj, "PufferOracle", address(pufferOracle));

        string memory finalJson = vm.serializeString(obj, "", "");
        vm.writeJson(finalJson, "./output/puffer.json");

        _setupAccess();

        return PufferDeployment({
            accessManager: address(accessManager),
            pufferDepositorImplementation: address(pufferDepositorImplementation),
            pufferDepositor: address(depositorProxy),
            pufferVault: address(vaultProxy),
            pufferVaultImplementation: address(pufferVaultImplementation),
            pufferOracle: address(pufferOracle),
            stETH: stETHAddress,
            timelock: address(timelock)
        });
    }

    function _setupAccess() internal {
        bytes[] memory upgraderCalldatas = _setupUpgrader();
        bytes[] memory otherCalldatas = _setupOther();

        bytes[] memory calldatas = new bytes[](upgraderCalldatas.length + otherCalldatas.length);

        // start index is 0
        for (uint256 i = 0; i < upgraderCalldatas.length; ++i) {
            calldatas[i] = upgraderCalldatas[i];
        }

        // start index is the one that ran previously (upgraderCalldatas.length)
        for (uint256 i = 0; i < otherCalldatas.length; ++i) {
            uint256 idx = upgraderCalldatas.length + i;
            calldatas[idx] = otherCalldatas[i];
        }

        accessManager.multicall(calldatas);
    }

    function _setupUpgrader() internal view returns (bytes[] memory) {
        bytes[] memory calldatas = new bytes[](4);

        bytes4[] memory selectors = new bytes4[](1);
        selectors[0] = UUPSUpgradeable.upgradeToAndCall.selector;

        // Restrict that selector on the Vault and Depositor

        calldatas[0] = abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector, address(vaultProxy), selectors, ROLE_ID_UPGRADER
        );
        calldatas[1] = abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector, address(pufferDepositor), selectors, ROLE_ID_UPGRADER
        );

        // Grant roles to operations & community

        // Operations Multisig has 7 day delay
        uint256 delayInSeconds = 604800; // 7 days
        calldatas[2] = abi.encodeWithSelector(
            AccessManager.grantRole.selector, ROLE_ID_UPGRADER, operationsMultisig, delayInSeconds
        );

        // Community has 0 delay
        calldatas[3] = abi.encodeWithSelector(AccessManager.grantRole.selector, ROLE_ID_UPGRADER, communityMultisig, 0);

        return calldatas;
    }

    function _setupOther() internal view returns (bytes[] memory) {
        bytes[] memory calldatas = new bytes[](5);

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = PufferVault.depositToEigenLayer.selector;
        selectors[1] = PufferVault.initiateETHWithdrawalsFromLido.selector;
        selectors[2] = PufferVault.initiateStETHWithdrawalFromEigenLayer.selector;

        // Setup setup role
        calldatas[0] = abi.encodeWithSelector(
            AccessManager.setTargetFunctionRole.selector, address(vaultProxy), selectors, ROLE_ID_OPERATIONS
        );

        // Setup role members (no delay)
        calldatas[1] =
            abi.encodeWithSelector(AccessManager.grantRole.selector, ROLE_ID_OPERATIONS, operationsMultisig, 0);
        // Grant admin role to timelock
        calldatas[2] =
            abi.encodeWithSelector(AccessManager.grantRole.selector, accessManager.ADMIN_ROLE(), address(timelock), 0);

        // Setup public access for PufferDepositor
        bytes4[] memory publicSelectors = new bytes4[](6);
        publicSelectors[0] = PufferDepositor.swapAndDeposit.selector;
        publicSelectors[1] = PufferDepositor.swapAndDepositWithPermit.selector;
        publicSelectors[2] = PufferDepositor.depositWstETH.selector;
        publicSelectors[3] = PufferDepositor.swapAndDepositWithPermit1Inch.selector;
        publicSelectors[4] = PufferDepositor.swapAndDeposit1Inch.selector;
        publicSelectors[5] = PufferDepositor.depositStETH.selector;

        calldatas[3] = abi.encodeCall(
            AccessManager.setTargetFunctionRole, (address(depositorProxy), publicSelectors, accessManager.PUBLIC_ROLE())
        );

        // Setup public access for PufferVault
        bytes4[] memory publicSelectorsPufferVault = new bytes4[](2);
        publicSelectorsPufferVault[0] = PufferVault.deposit.selector;
        publicSelectorsPufferVault[1] = PufferVault.mint.selector;

        calldatas[4] = abi.encodeCall(
            AccessManager.setTargetFunctionRole,
            (address(vaultProxy), publicSelectorsPufferVault, accessManager.PUBLIC_ROLE())
        );

        return calldatas;
    }

    function _getArgs()
        internal
        returns (
            IStETH stETH,
            ILidoWithdrawalQueue lidoWithdrawalQueue,
            IStrategy stETHStrategy,
            IEigenLayer eigenStrategyManager
        )
    {
        if (isMainnet()) {
            stETH = _ST_ETH;
            lidoWithdrawalQueue = _LIDO_WITHDRAWAL_QUEUE;
            stETHStrategy = _EIGEN_STETH_STRATEGY;
            eigenStrategyManager = _EIGEN_STRATEGY_MANAGER;
        } else {
            stETH = IStETH(address(new stETHMock()));
            lidoWithdrawalQueue = new LidoWithdrawalQueueMock();
            stETHStrategy = new stETHStrategyMock();
            eigenStrategyManager = new EigenLayerManagerMock();
        }
    }
}
