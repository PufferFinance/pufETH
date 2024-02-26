// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { PufferDepositor } from "../src/PufferDepositor.sol";
import { PufferVaultV2 } from "../src/PufferVaultV2.sol";
import { PufferDepositorV2 } from "../src/PufferDepositorV2.sol";
import { MockPufferOracle } from "./mocks/MockPufferOracle.sol";
import { IEigenLayer } from "../src/interface/EigenLayer/IEigenLayer.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UUPSUpgradeable } from "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { stdStorage, StdStorage } from "forge-std/Test.sol";
import { PufferVault } from "../src/PufferVault.sol";
import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";
import { IStETH } from "../src/interface/Lido/IStETH.sol";
import { IWstETH } from "../src/interface/Lido/IWstETH.sol";
import { ILidoWithdrawalQueue } from "../src/interface/Lido/ILidoWithdrawalQueue.sol";
import { IStrategy } from "../src/interface/EigenLayer/IStrategy.sol";
import { Timelock } from "../src/Timelock.sol";
import { IWETH } from "../src/interface/Other/IWETH.sol";
import { GenerateAccessManagerCallData } from "script/GenerateAccessManagerCallData.sol";
import { Permit } from "../src/structs/Permit.sol";
import { ERC1967Utils } from "openzeppelin/proxy/ERC1967/ERC1967Utils.sol";

contract TestHelper is Test {
    /**
     * @dev Ethereum Mainnet addresses
     */
    IStrategy internal constant _EIGEN_STETH_STRATEGY = IStrategy(0x93c4b944D05dfe6df7645A86cd2206016c51564D);
    IEigenLayer internal constant _EIGEN_STRATEGY_MANAGER = IEigenLayer(0x858646372CC42E1A627fcE94aa7A7033e7CF075A);
    IStETH internal constant _ST_ETH = IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IWETH internal constant _WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IWstETH internal constant _WST_ETH = IWstETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    ILidoWithdrawalQueue internal constant _LIDO_WITHDRAWAL_QUEUE =
        ILidoWithdrawalQueue(0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1);

    using stdStorage for StdStorage;

    bytes32 private constant _PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    struct _TestTemps {
        address owner;
        address to;
        uint256 amount;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 privateKey;
        uint256 nonce;
        bytes32 domainSeparator;
    }

    PufferDepositorV2 public pufferDepositor;
    PufferVaultV2 public pufferVault;
    AccessManager public accessManager;
    Timelock public timelock;

    // Lido contract (stETH)
    IStETH stETH = IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    // EL Strategy Manager
    IEigenLayer eigenStrategyManager = IEigenLayer(0x858646372CC42E1A627fcE94aa7A7033e7CF075A);

    address alice = makeAddr("alice");
    // Bob..
    address bob;
    uint256 bobSK;
    address charlie = makeAddr("charlie");
    address dave = makeAddr("dave");
    address eve = makeAddr("eve");

    // Use Binance exchange address for mainnet fork tests to get ETH + erc20s
    address BINANCE = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
    // Use Maker address for mainnet fork tests to get wETH
    address MAKER_VAULT = 0x2F0b23f53734252Bda2277357e97e1517d6B042A;
    // Use Blast deposit contract for mainnet fork tests to get stETH
    address BLAST_DEPOSIT = 0x5F6AE08B8AeB7078cf2F96AFb089D7c9f51DA47d;
    // Convex Whale
    address CVX_WHALE = 0x72a19342e8F1838460eBFCCEf09F6585e32db86E;

    // Token addresses
    address CVX = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B;
    address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address APE = 0x4d224452801ACEd8B2F0aebE155379bb5D594381;

    address LIDO_WITHDRAWAL_QUEUE = 0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1;
    address LIDO_ACCOUNTING_ORACLE = 0x852deD011285fe67063a08005c71a85690503Cee;

    // Storage slot for the Consensus Layer Balance in stETH
    bytes32 internal constant CL_BALANCE_POSITION = 0xa66d35f054e68143c18f32c990ed5cb972bb68a68f500cd2dd3a16bbf3686483; // keccak256("lido.Lido.beaconBalance");

    address COMMUNITY_MULTISIG;
    address OPERATIONS_MULTISIG;

    address mockPufferProtocol = makeAddr("mockPufferProtocol");

    // Transfer `token` from `from` to `to` to fill accounts in mainnet fork tests
    modifier giveToken(address from, address token, address to, uint256 amount) {
        vm.startPrank(from);
        SafeERC20.safeTransfer(IERC20(token), to, amount);
        vm.stopPrank();
        _;
    }

    modifier withCaller(address caller) {
        vm.startPrank(caller);
        _;
        vm.stopPrank();
    }

    function setUp() public virtual {
        vm.createSelectFork(vm.rpcUrl("mainnet"), 19271279);

        // Setup contracts that are deployed to mainnet
        _setupLiveContracts();

        // Upgrade to latest version
        _upgradeToMainnetPuffer();
    }

    function _setupLiveContracts() internal {
        pufferDepositor = PufferDepositorV2(payable(0x4aA799C5dfc01ee7d790e3bf1a7C2257CE1DcefF));
        pufferVault = PufferVaultV2(payable(0xD9A442856C234a39a81a089C06451EBAa4306a72));
        accessManager = AccessManager(payable(0x8c1686069474410E6243425f4a10177a94EBEE11));
        timelock = Timelock(payable(0x3C28B7c7Ba1A1f55c9Ce66b263B33B204f2126eA));

        COMMUNITY_MULTISIG = timelock.COMMUNITY_MULTISIG();
        OPERATIONS_MULTISIG = timelock.OPERATIONS_MULTISIG();

        vm.label(COMMUNITY_MULTISIG, "COMMUNITY_MULTISIG");
        vm.label(OPERATIONS_MULTISIG, "OPERATIONS_MULTISIG");
        vm.label(address(stETH), "stETH");
        vm.label(address(pufferDepositor), "PufferDepositorProxy");
        vm.label(address(pufferVault), "PufferVaultProxy");
        vm.label(address(accessManager), "AccessManager");
        vm.label(0x17144556fd3424EDC8Fc8A4C940B2D04936d17eb, "stETH implementation");
        vm.label(0x2b33CF282f867A7FF693A66e11B0FcC5552e4425, "stETH kernel");
        vm.label(address(APE), "APE");
        vm.label(address(USDT), "USDT");
        vm.label(address(USDC), "USDC");
        vm.label(address(_WETH), "WETH");
        vm.label(0x1111111254EEB25477B68fb85Ed929f73A960582, "1Inch router");
        vm.label(BINANCE, "BINANCE exchange");
        vm.label(MAKER_VAULT, "MAKER Vault");
        vm.label(0x93c4b944D05dfe6df7645A86cd2206016c51564D, "Eigen stETH strategy");

        (bob, bobSK) = makeAddrAndKey("bob");
    }

    function _upgradeToMainnetPuffer() internal {
        // We use MockOracle + MockPufferProtocol to simulate the Puffer Protocol
        MockPufferOracle mockOracle = new MockPufferOracle();

        // Simulate that our deployed oracle becomes active and starts posting results of Puffer staking
        // At this time, we stop accepting stETH, and we accept only native ETH
        PufferVaultV2 newImplementation = new PufferVaultV2(
            _ST_ETH, _WETH, _LIDO_WITHDRAWAL_QUEUE, _EIGEN_STETH_STRATEGY, _EIGEN_STRATEGY_MANAGER, mockOracle
        );

        // Community multisig can do thing instantly
        vm.startPrank(COMMUNITY_MULTISIG);

        //Upgrade PufferVault

        //@todo To go this way, we need to setTargetRole for upgradeToAndCall to `0` (admin role of AccessManager)
        // timelock.executeTransaction(
        //     address(pufferVault),
        //     abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(newImplementation), abi.encodeCall(PufferVaultV2.initialize, ()))),
        //     1
        // );

        vm.expectEmit(true, true, true, true);
        emit ERC1967Utils.Upgraded(address(newImplementation));
        UUPSUpgradeable(pufferVault).upgradeToAndCall(
            address(newImplementation), abi.encodeCall(PufferVaultV2.initialize, ())
        );

        // Upgrade PufferDepositor

        PufferDepositorV2 newDepositorImplementation =
            new PufferDepositorV2(PufferVaultV2(payable(pufferVault)), _ST_ETH);

        // Upgrade PufferDepositor - no initializer here
        emit ERC1967Utils.Upgraded(address(newDepositorImplementation));
        timelock.executeTransaction(
            address(pufferDepositor),
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(newDepositorImplementation), "")),
            1
        );

        // Setup access

        bytes memory encodedMulticall =
            new GenerateAccessManagerCallData().run(address(pufferVault), address(pufferDepositor));
        // Timelock is the owner of the AccessManager
        timelock.executeTransaction(address(accessManager), encodedMulticall, 1);

        vm.stopPrank();
    }

    function _signPermit(_TestTemps memory t) internal pure returns (Permit memory p) {
        bytes32 innerHash = keccak256(abi.encode(_PERMIT_TYPEHASH, t.owner, t.to, t.amount, t.nonce, t.deadline));
        bytes32 domainSeparator = t.domainSeparator;
        bytes32 outerHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, innerHash));
        (t.v, t.r, t.s) = vm.sign(t.privateKey, outerHash);

        return Permit({ deadline: t.deadline, amount: t.amount, v: t.v, r: t.r, s: t.s });
    }

    function _finalizeWithdrawals(uint256 requestIdFinalized) internal {
        // Alter WithdrawalRouter storage slot to mark our withdrawal requests as finalized
        vm.store(
            LIDO_WITHDRAWAL_QUEUE,
            keccak256("lido.WithdrawalQueue.lastFinalizedRequestId"),
            bytes32(uint256(requestIdFinalized))
        );
    }

    function _testTemps(string memory seed, address to, uint256 amount, uint256 deadline, bytes32 domainSeparator)
        internal
        returns (_TestTemps memory t)
    {
        (t.owner, t.privateKey) = makeAddrAndKey(seed);
        t.to = to;
        t.amount = amount;
        t.deadline = deadline;
        t.domainSeparator = domainSeparator;
    }
}
