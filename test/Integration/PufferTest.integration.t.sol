// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { PufferDepositor } from "../../src/PufferDepositor.sol";
import { PufferVaultMainnet } from "../../src/PufferVaultMainnet.sol";
import { PufferOracle } from "../../src/PufferOracle.sol";
import { IStETH } from "../../src/interface/Lido/IStETH.sol";
import { IPufferDepositor } from "../../src/interface/IPufferDepositor.sol";
import { IEigenLayer } from "src/interface/EigenLayer/IEigenLayer.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UUPSUpgradeable } from "@openzeppelin-contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { Initializable } from "openzeppelin/proxy/utils/Initializable.sol";
import { DeployPuffETH } from "script/DeployPuffETH.s.sol";
import { PufferDeployment } from "src/structs/PufferDeployment.sol";
import { stdStorage, StdStorage } from "forge-std/Test.sol";
import { PufferVault } from "src/PufferVault.sol";
import { AccessManager } from "openzeppelin/access/manager/AccessManager.sol";
import { IStETH } from "src/interface/Lido/IStETH.sol";
import { IWstETH } from "src/interface/Lido/IWstETH.sol";
import { ILidoWithdrawalQueue } from "src/interface/Lido/ILidoWithdrawalQueue.sol";
import { IEigenLayer } from "src/interface/EigenLayer/IEigenLayer.sol";
import { IStrategy } from "src/interface/EigenLayer/IStrategy.sol";

contract PufferTest is Test {
    /**
     * @dev Ethereum Mainnet addresses
     */
    IStrategy internal constant _EIGEN_STETH_STRATEGY = IStrategy(0x93c4b944D05dfe6df7645A86cd2206016c51564D);
    IEigenLayer internal constant _EIGEN_STRATEGY_MANAGER = IEigenLayer(0x858646372CC42E1A627fcE94aa7A7033e7CF075A);
    IStETH internal constant _ST_ETH = IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
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

    PufferDepositor public pufferDepositor;
    PufferVault public pufferVault;
    AccessManager public accessManager;
    PufferOracle public pufferOracle;

    // Lido contract (stETH)
    IStETH stETH = IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IERC20 internal constant _WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    // EL Strategy Manager
    IEigenLayer eigenStrategyManager = IEigenLayer(0x858646372CC42E1A627fcE94aa7A7033e7CF075A);

    address alice = makeAddr("alice");
    // Bob..
    address bob;
    uint256 bobSK;
    address charlie = makeAddr("charlie");
    address dave = makeAddr("dave");
    address eve = makeAddr("eve");

    // We are taking CZ's money
    address BINANCE = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
    // Maker got WETH
    address MAKER_VAULT = 0x2F0b23f53734252Bda2277357e97e1517d6B042A;
    // Binance doesn't hold stETH, we need to take it from Blast deposit contract
    address BLAST_DEPOSIT = 0x5F6AE08B8AeB7078cf2F96AFb089D7c9f51DA47d;

    // Token addresses
    address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address APE = 0x4d224452801ACEd8B2F0aebE155379bb5D594381;

    address LIDO_WITHDRAWAL_QUEUE = 0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1;
    address LIDO_ACCOUNTING_ORACLE = 0x852deD011285fe67063a08005c71a85690503Cee;

    // Storage slot for the Consensus Layer Balance in stETH
    bytes32 internal constant CL_BALANCE_POSITION = 0xa66d35f054e68143c18f32c990ed5cb972bb68a68f500cd2dd3a16bbf3686483; // keccak256("lido.Lido.beaconBalance");

    address COMMUNITY_MULTISIG = makeAddr("pufferDeployer"); // In this case the deployer is 'multisig'
    address OPERATIONS_MULTISIG = makeAddr("operations");

    function setUp() public {
        // 1 block after allowance increase for stETH on EL
        // https://etherscan.io/tx/0xc16610a3dc3e8732e3fbb7761f6e1c0e44869cba5a41b058d2b3abce98833667
        vm.createSelectFork(vm.rpcUrl("mainnet"), 18812842);

        // Deploy the contracts on the fork above
        _setupContracts();
    }

    function _setupContracts() internal {
        PufferDeployment memory deployment = new DeployPuffETH().run();
        pufferDepositor = PufferDepositor(payable(deployment.pufferDepositor));
        pufferVault = PufferVault(payable(deployment.pufferVault));
        accessManager = AccessManager(payable(deployment.accessManager));
        pufferOracle = PufferOracle(payable(deployment.pufferOracle));

        // vm.startPrank(COMMUNITY_MULTISIG);
        // pufferDepositor.allowToken(IERC20(APE));
        // vm.stopPrank();

        vm.label(address(stETH), "stETH");
        vm.label(address(APE), "APE");
        vm.label(address(USDT), "USDT");
        vm.label(address(USDC), "USDC");
        vm.label(BINANCE, "BINANCE exchange");
        vm.label(MAKER_VAULT, "MAKER Vault");
        vm.label(0x93c4b944D05dfe6df7645A86cd2206016c51564D, "Eigen stETH strategy");

        (bob, bobSK) = makeAddrAndKey("bob");
    }

    function _setupUsdcFork() internal {
        // USDC token got an upgrade, because of that we create another fork, to test that it works
        // https://www.circle.com/blog/announcing-usdc-v2.2
        vm.createSelectFork(vm.rpcUrl("mainnet"), 19011889);
        _setupContracts();
    }

    // Transfer `token` from Binance to `to`
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

    modifier deployNewUsdc() {
        // Workaround for deploying new usdc fork
        // This modifier needs to be called first
        _setupUsdcFork();
        _;
    }

    function _increaseELstETHCap() public {
        // This function is simulating a rebase from this transaction
        // https://etherscan.io/tx/0xc16610a3dc3e8732e3fbb7761f6e1c0e44869cba5a41b058d2b3abce98833667
        vm.roll(18819958);
        vm.startPrank(0xe7fFd467F7526abf9c8796EDeE0AD30110419127); // EL
        (bool success,) = 0xBE1685C81aA44FF9FB319dD389addd9374383e90.call( // El Multisig
            hex"6a761202000000000000000000000000a6db1a8c5a981d1536266d2a393c5f8ddb210eaf00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000074000000000000000000000000000000000000000000000000000000000000005c40825f38f000000000000000000000000369e6f597e22eab55ffb173c6d9cd234bd699111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000657eb4f30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004a46a76120200000000000000000000000040a2accbd92bca938b02010e17a5b8929b49130d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000140000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000042000000000000000000000000000000000000000000000000000000000000002a48d80ff0a000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000002440093c4b944d05dfe6df7645a86cd2206016c51564d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004411c70c9d000000000000000000000000000000000000000000002a5a058fc295ed000000000000000000000000000000000000000000000000002a5a058fc295ed000000001bee69b7dfffa4e2d53c2a2df135c388ad25dcd20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004411c70c9d000000000000000000000000000000000000000000002a5a058fc295ed000000000000000000000000000000000000000000000000002a5a058fc295ed0000000054945180db7943c0ed0fee7edab2bd24620256bc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004411c70c9d000000000000000000000000000000000000000000002a5a058fc295ed000000000000000000000000000000000000000000000000002a5a058fc295ed00000000858646372cc42e1a627fce94aa7a7033e7cf075a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000024fabc1cbc000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041000000000000000000000000a6db1a8c5a981d1536266d2a393c5f8ddb210eaf00000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c30b32ae3865c0fd6cc396243889688a34f95c45a9110fe0aadc60b2a6e99e383d5d67668ffa2f5481f0003d26a5aa6b07746dd6b6162db411c585f31483efd6961b000000000000000000000000e7ffd467f7526abf9c8796edee0ad30110419127000000000000000000000000000000000000000000000000000000000000000001e3d807e6e26f9702b76782c559ef94158f44da655c8eb4e5d26f1e7cea4ef6287fa6b6da3baae46e6f8da28111d64ab62e07a0f4b80d3e418e1f8b89d62b34621c0000000000000000000000000000000000000000000000000000000000"
        );
        assertTrue(success, "oracle rebase failed");
        vm.stopPrank();
    }

    function _rebaseLido() internal {
        // This function is simulating a rebase from this transaction
        // https://etherscan.io/tx/0xc308f3173b7a73b62751c42b5349203fa2684ad9b977cac5daf74582ff87d9ab
        vm.roll(18819958);
        vm.startPrank(0x140Bd8FbDc884f48dA7cb1c09bE8A2fAdfea776E); // Whitelisted Oracle
        (bool success,) = LIDO_ACCOUNTING_ORACLE.call(
            hex"fc7377cd00000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000007a2aff000000000000000000000000000000000000000000000000000000000004b6bb00000000000000000000000000000000000000000000000000207cc3840da37700000000000000000000000000000000000000000000000000000000000001e000000000000000000000000000000000000000000000000000000000000002200000000000000000000000000000000000000000000000291edebdc938e7a00000000000000000000000000000000000000000000000000d37c862e1201902f400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000003b7c24bbc12e7a67c59354500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001af7a147aadae04565041a10836ae2210426a05e5e4d60834a4d8ebc716f2948c000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000060cb00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000004918"
        );
        assertTrue(success, "oracle rebase failed");
        vm.stopPrank();
    }

    function _finalizeWithdrawals(uint256 requestIdFinalized) internal {
        // Alter WithdrawalRouter storage slot to mark our withdrawal requests as finalized
        vm.store(
            LIDO_WITHDRAWAL_QUEUE,
            keccak256("lido.WithdrawalQueue.lastFinalizedRequestId"),
            bytes32(uint256(requestIdFinalized))
        );
    }

    function _upgradeToMainnetPuffer() internal {
        // Simulate that our deployed oracle becomes active and starts posting results of Puffer staking
        // At this time, we stop accepting stETH, and we accept only native ETH
        PufferVaultMainnet newImplementation =
            new PufferVaultMainnet(_ST_ETH, _LIDO_WITHDRAWAL_QUEUE, _EIGEN_STETH_STRATEGY, _EIGEN_STRATEGY_MANAGER);

        // Community multisig can do thing instantly
        vm.startPrank(COMMUNITY_MULTISIG);

        vm.expectEmit(true, true, true, true);
        emit Initializable.Initialized(2);
        UUPSUpgradeable(pufferVault).upgradeToAndCall(
            address(newImplementation), abi.encodeCall(PufferVaultMainnet.initialize, ())
        );
        vm.stopPrank();
    }

    function test_upgrade_from_operations_multisig() public {
        PufferVaultMainnet newImplementation =
            new PufferVaultMainnet(_ST_ETH, _LIDO_WITHDRAWAL_QUEUE, _EIGEN_STETH_STRATEGY, _EIGEN_STRATEGY_MANAGER);

        // Community multisig can do thing instantly, this one has a delay
        vm.startPrank(OPERATIONS_MULTISIG);

        bytes memory initializerCallData = abi.encodeCall(PufferVaultMainnet.initialize, ());

        // It is not allowed to execute before the timelock
        vm.expectRevert();
        accessManager.execute(
            address(pufferVault),
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(newImplementation), initializerCallData))
        );

        // 1. Schedule the upgrade
        accessManager.schedule(
            address(pufferVault),
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(newImplementation), initializerCallData)),
            0
        );

        vm.warp(block.timestamp + 7 days);

        vm.expectEmit(true, true, true, true);
        emit Initializable.Initialized(2);
        // 2. Execute the upgrade
        accessManager.execute(
            address(pufferVault),
            abi.encodeCall(UUPSUpgradeable.upgradeToAndCall, (address(newImplementation), initializerCallData))
        );
    }

    function test_upgrade_to_mainnet() public giveToken(MAKER_VAULT, address(_WETH), eve, 100 ether) {
        // Test pre-mainnet version
        test_minting_and_lido_rebasing();

        uint256 assetsBefore = pufferVault.totalAssets();

        // Upgrade to mainnet
        _upgradeToMainnetPuffer();

        vm.startPrank(eve);
        SafeERC20.safeIncreaseAllowance(_WETH, address(pufferVault), type(uint256).max);

        uint256 wethBeforeEve = _WETH.balanceOf(eve);

        uint256 pufETHMinted = pufferVault.deposit(100 ether, eve);

        assertEq(pufferVault.totalAssets(), assetsBefore + 100 ether, "Previous assets should increase");

        pufferVault.withdraw(pufETHMinted, eve, eve);

        // 0.01% is the max delta because of the rounding
        // Real delta is 0.009900175912953700 %
        assertApproxEqRel(_WETH.balanceOf(eve), wethBeforeEve, 0.0001e18, "eve weth after withdrawal");
        assertApproxEqRel(pufferVault.totalAssets(), assetsBefore, 0.0001e18, "should have the same amount");
    }

    function test_minting_and_lido_rebasing()
        public
        giveToken(BLAST_DEPOSIT, address(stETH), alice, 1000 ether) // Blast got a lot of stETH
        giveToken(BLAST_DEPOSIT, address(stETH), bob, 1000 ether)
    {
        // Pretend that alice is depositing 1k ETH
        vm.startPrank(alice);
        SafeERC20.safeIncreaseAllowance(IERC20(stETH), address(pufferVault), type(uint256).max);
        uint256 aliceMinted = pufferVault.deposit(1000 ether, alice);

        assertGt(aliceMinted, 0, "alice minted");

        // Save total ETH backing before the rebase
        uint256 backingETHAmountBefore = pufferVault.totalAssets();

        // Check the balance before rebase
        uint256 stethBalanceBefore = IERC20(stETH).balanceOf(address(pufferVault));

        _rebaseLido();

        assertTrue(pufferVault.totalAssets() > backingETHAmountBefore, "eth backing went down");

        // Check the balance after rebase and assert that it increased
        uint256 stethBalanceAfter = IERC20(stETH).balanceOf(address(pufferVault));

        assertTrue(stethBalanceAfter > stethBalanceBefore, "lido rebase failed");

        // After rebase, Bob is depositing 1k ETH
        vm.startPrank(bob);
        SafeERC20.safeIncreaseAllowance(IERC20(stETH), address(pufferVault), type(uint256).max);
        uint256 bobMinted = pufferVault.deposit(1000 ether, bob);

        // Alice should have more pufferDepositor because the rebase happened after her deposit and changed the rate
        assertTrue(aliceMinted > bobMinted, "alice should have more");

        // ETH Backing after rebase should go up
        assertTrue(pufferVault.totalAssets() > backingETHAmountBefore, "eth backing went down");
    }

    function test_depositingStETH_and_withdrawal() public {
        test_minting_and_lido_rebasing();

        // Check the balance of our vault
        uint256 balance = stETH.balanceOf(address(address(pufferVault)));

        // We deposited 2k ETH, but because of the rebase we have more than 2k
        //
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1000 ether; // steth Amount
        amounts[1] = 1000 ether; // steth Amount
        amounts[2] = balance - 2000 ether; // the test

        uint256 assetsBefore = pufferVault.totalAssets();

        // Initiate Withdrawals from lido
        vm.startPrank(COMMUNITY_MULTISIG);
        uint256[] memory requestIds = pufferVault.initiateETHWithdrawalsFromLido(amounts);

        assertApproxEqRel(assetsBefore, pufferVault.totalAssets(), 0.001e18, "bad accounting");

        // Finalize them and fast forward to +10 days
        _finalizeWithdrawals(requestIds[2]);
        vm.roll(block.number + 10 days); // stupid bug

        // Claim withdrawals
        pufferVault.claimWithdrawalsFromLido(requestIds);

        // Assert that we got more ETH than our original 2k ETH
        assertGt(address(pufferVault).balance, 2000 ether, "oh no");
    }

    function test_usdt_to_pufETH() public giveToken(BINANCE, USDT, alice, 2_175_000_000) withCaller(alice) {
        uint256 tokenInAmount = 2_175_000_000; // 2175 USDT

        // Manually edited the route code for USDT -> stETH
        // Last 20 bytes is the address of where the stETH is going
        // (AdEa807cE68B17a32cE7CB80757c1B16cBca7887) is the address of PufferDepositor
        bytes memory routeCode =
            hex"02dAC17F958D2ee523a2206206994597C13D831ec701ffff01c7bBeC68d12a0d1830360F8Ec58fA599bA1b0e9b004028DAAC072e492d34a3Afdbef0ba7e35D8b55C404C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2004028DAAC072e492d34a3Afdbef0ba7e35D8b55C400AdEa807cE68B17a32cE7CB80757c1B16cBca7887";

        assertEq(pufferVault.balanceOf(alice), 0, "alice has 0 pufETH");

        // USDT doesn't have a permit, so the user needs to approve it to our contract
        SafeERC20.safeIncreaseAllowance(IERC20(USDT), address(pufferDepositor), type(uint256).max);
        pufferDepositor.swapAndDeposit({ amountIn: tokenInAmount, tokenIn: USDT, amountOutMin: 0, routeCode: routeCode });

        assertGt(pufferVault.balanceOf(alice), 0, "alice pufETH");
        assertGt(stETH.balanceOf(address(pufferVault)), 0, "pufferVault should hold stETH");
    }

    function test_usdc_to_pufETH() public giveToken(BINANCE, USDC, dave, 20_000_000_000) withCaller(dave) {
        uint256 tokenInAmount = 20_000_000_000; // 20k USDC

        // Manually edited the route code for USDC -> stETH
        // Last 20 bytes is the address of where the stETH is going
        // (AdEa807cE68B17a32cE7CB80757c1B16cBca7887) is the address of pufferDepositor
        bytes memory routeCode =
            hex"02A0b86991c6218b36c1d19D4a2e9Eb0cE3606eB4801ffff0188e6A0c2dDD26FEEb64F039a2c41296FcB3f5640014028DAAC072e492d34a3Afdbef0ba7e35D8b55C404C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2004028DAAC072e492d34a3Afdbef0ba7e35D8b55C400AdEa807cE68B17a32cE7CB80757c1B16cBca7887";

        assertEq(pufferVault.balanceOf(dave), 0, "dave has 0 pufETH");

        // USDT doesn't have a permit, so the user needs to approve it to our contract
        SafeERC20.safeIncreaseAllowance(IERC20(USDC), address(pufferDepositor), type(uint256).max);
        pufferDepositor.swapAndDeposit({ amountIn: tokenInAmount, tokenIn: USDC, amountOutMin: 0, routeCode: routeCode });

        assertGt(pufferVault.balanceOf(dave), 0, "dave pufETH");
    }

    function test_ape_to_pufETH() public giveToken(BINANCE, APE, charlie, 1000 ether) withCaller(charlie) {
        uint256 tokenInAmount = 1000 ether; // 1000 APE

        // Manually edited the route code for APE -> stETH
        // Last 20 bytes is the address of where the stETH is going
        // (AdEa807cE68B17a32cE7CB80757c1B16cBca7887) is the address of pufferDepositor
        bytes memory routeCode =
            hex"024d224452801ACEd8B2F0aebE155379bb5D59438101ffff00130F4322e5838463ee460D5854F5D472cFC8f25301e43D6AAFce76f53670C4b7D6B38A7D8a67a4B67004C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc200e43D6AAFce76f53670C4b7D6B38A7D8a67a4B67000AdEa807cE68B17a32cE7CB80757c1B16cBca7887";

        assertEq(pufferVault.balanceOf(charlie), 0, "charlie has 0 pufETH");

        // USDT doesn't have a permit, so the user needs to approve it to our contract
        SafeERC20.safeIncreaseAllowance(IERC20(APE), address(pufferDepositor), type(uint256).max);
        pufferDepositor.swapAndDeposit({ amountIn: tokenInAmount, tokenIn: APE, amountOutMin: 0, routeCode: routeCode });

        assertGt(pufferVault.balanceOf(charlie), 0, "charlie pufETH");
    }

    function test_deposit_wstETH_permit()
        public
        giveToken(0x0B925eD163218f6662a35e0f0371Ac234f9E9371, address(_WST_ETH), alice, 3000 ether)
        withCaller(alice)
    {
        assertEq(0, pufferVault.balanceOf(alice), "alice has 0 pufETH");

        IPufferDepositor.Permit memory permit = _signPermit(
            _testTemps(
                "alice",
                address(pufferDepositor),
                3000 ether,
                block.timestamp,
                hex"d4a8ff90a402dc7d4fcbf60f5488291263c743ccff180e139f47d139cedfd5fe"
            )
        );

        // Permit is good in this case
        pufferDepositor.depositWstETH(permit);

        assertGt(pufferVault.balanceOf(alice), 0, "alice got pufETH");
    }

    function test_deposit_wstETH()
        public
        giveToken(0x0B925eD163218f6662a35e0f0371Ac234f9E9371, address(_WST_ETH), alice, 3000 ether)
        withCaller(alice)
    {
        IERC20(address(_WST_ETH)).approve(address(pufferDepositor), type(uint256).max);

        assertEq(0, pufferVault.balanceOf(alice), "alice has 0 pufETH");

        IPufferDepositor.Permit memory permit =
            _signPermit(_testTemps("alice", address(pufferDepositor), 3000 ether, block.timestamp, hex""));

        // Permit call will revert because of the bad domain separator for wstETH
        // But because we did the .approve, the transaction will succeed
        pufferDepositor.depositWstETH(permit);

        assertGt(pufferVault.balanceOf(alice), 0, "alice got pufETH");
    }

    function test_usdc_to_pufETH_permit() public giveToken(BINANCE, USDC, bob, 10_000_000_000) withCaller(bob) {
        uint256 tokenInAmount = 10_000_000_000; // 10k USDC

        // To get the route code
        // Change tokenIn, and to if needed
        // https://swap.sushi.com/v3.2?chainId=1&tokenIn=0xF629cBd94d3791C9250152BD8dfBDF380E2a3B9c&tokenOut=0xAdEa807cE68B17a32cE7CB80757c1B16cBca7887&amount=2000000000&maxPriceImpact=0.005&gasPrice=33538046487&to=0xAdEa807cE68B17a32cE7CB80757c1B16cBca7887&preferSushi=false

        // Manually edited the route code for USDC -> stETH
        // Last 20 bytes is the address of where the stETH is going
        // (AdEa807cE68B17a32cE7CB80757c1B16cBca7887) is the address of pufferDepositor
        bytes memory routeCode =
            hex"02A0b86991c6218b36c1d19D4a2e9Eb0cE3606eB4801ffff0188e6A0c2dDD26FEEb64F039a2c41296FcB3f5640014028DAAC072e492d34a3Afdbef0ba7e35D8b55C404C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2004028DAAC072e492d34a3Afdbef0ba7e35D8b55C400AdEa807cE68B17a32cE7CB80757c1B16cBca7887";

        assertEq(pufferVault.balanceOf(bob), 0, "bob has 0 pufETH");

        IPufferDepositor.Permit memory permit = _signPermit(
            _testTemps(
                "bob",
                address(pufferDepositor),
                tokenInAmount,
                block.timestamp,
                hex"06c37168a7db5138defc7866392bb87a741f9b3d104deb5094588ce041cae335"
            )
        );

        // USDT doesn't have a permit, so the user needs to approve it to our contract
        pufferDepositor.swapAndDepositWithPermit({
            tokenIn: USDC,
            amountOutMin: 0,
            permitData: permit,
            routeCode: routeCode
        });

        assertGt(pufferVault.balanceOf(bob), 0, "bob pufETH");
    }

    // Almost the same test as the one above, but on newer fork with a newer USDC version
    function test_usdc_permit_upgrade()
        public
        deployNewUsdc
        giveToken(BINANCE, USDC, bob, 10_000_000_000)
        withCaller(bob)
    {
        uint256 tokenInAmount = 10_000_000_000; // 10k USDC

        bytes memory routeCode =
            hex"02A0b86991c6218b36c1d19D4a2e9Eb0cE3606eB4801ffff0188e6A0c2dDD26FEEb64F039a2c41296FcB3f5640014028DAAC072e492d34a3Afdbef0ba7e35D8b55C404C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2004028DAAC072e492d34a3Afdbef0ba7e35D8b55C400AdEa807cE68B17a32cE7CB80757c1B16cBca7887";

        assertEq(pufferVault.balanceOf(bob), 0, "bob has 0 pufETH");

        IPufferDepositor.Permit memory permit = _signPermit(
            _testTemps(
                "bob",
                address(pufferDepositor),
                tokenInAmount,
                block.timestamp,
                hex"06c37168a7db5138defc7866392bb87a741f9b3d104deb5094588ce041cae335"
            )
        );

        // USDT doesn't have a permit, so the user needs to approve it to our contract
        pufferDepositor.swapAndDepositWithPermit({
            tokenIn: USDC,
            amountOutMin: 0,
            permitData: permit,
            routeCode: routeCode
        });

        assertGt(pufferVault.balanceOf(bob), 0, "bob got pufETH");
    }

    function test_conversions_and_deposit_to_el() public {
        // Rough estimations:
        // Block number 18812842 is Dec-18-2023 12:21:35 PM +UTC)
        // Here is historical data https://coinmarketcap.com/historical/20231217/ for 17th december

        // Swap various tokens
        test_ape_to_pufETH(); // 1000 APE = 1678 USDT
        test_usdc_to_pufETH(); // 20k USDC
        test_usdc_to_pufETH_permit(); // 10k USDC
        test_usdt_to_pufETH(); // 2175 USDT

        // 1678$ + 20000$ + 10000$ + 2175$ = 33853$ ~ 15.41 ETH (expected output in ideal conditions)
        // On that date 1 ETH ~ 2196$
        // At the end we have ~ 14,79 ETH

        // Because of the multi pool swaps, it looks ok

        // From 14.71 -> 15.41 is +4.192% diff
        // From 15.41 -> 14.71 is -4% diff

        // Simulate stETH cap increase call on EL
        _increaseELstETHCap();

        // Deposit to EL
        vm.startPrank(COMMUNITY_MULTISIG);
        pufferVault.depositToEigenLayer(stETH.balanceOf(address(pufferVault)));

        assertGt(_EIGEN_STETH_STRATEGY.userUnderlying(address(pufferVault)), 0, "no deposit to EL from the Vault");

        // Get total ETH backing of our system
        uint256 totalETHBackingAmount = pufferVault.totalAssets();

        // Got ~ 14.79 ETH assert with 0.4% tolerance
        assertApproxEqRel(totalETHBackingAmount, 14.79 ether, 0.4e18, "got eth");
    }

    function test_withdraw_from_eigenLayer()
        public
        giveToken(BLAST_DEPOSIT, address(stETH), address(pufferVault), 1000 ether) // Blast got a lot of stETH
    {
        // Simulate stETH cap increase call on EL
        _increaseELstETHCap();

        vm.startPrank(OPERATIONS_MULTISIG);
        pufferVault.depositToEigenLayer(stETH.balanceOf(address(pufferVault)));

        uint256 ownedShares = _EIGEN_STRATEGY_MANAGER.stakerStrategyShares(address(pufferVault), _EIGEN_STETH_STRATEGY);

        uint256 assetsBefore = pufferVault.totalAssets();

        // Initiate the withdrawal
        pufferVault.initiateStETHWithdrawalFromEigenLayer(ownedShares);

        // 1 wei diff because of rounding
        assertApproxEqAbs(assetsBefore, pufferVault.totalAssets(), 1, "should remain the same when locked");

        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(address(stETH));

        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = IStrategy(_EIGEN_STETH_STRATEGY);

        uint256[] memory shares = new uint256[](1);
        shares[0] = ownedShares;

        IEigenLayer.WithdrawerAndNonce memory withdrawerAndNonce =
            IEigenLayer.WithdrawerAndNonce({ withdrawer: address(pufferVault), nonce: 0 });

        IEigenLayer.QueuedWithdrawal memory queuedWithdrawal = IEigenLayer.QueuedWithdrawal({
            strategies: strategies,
            shares: shares,
            depositor: address(pufferVault),
            withdrawerAndNonce: withdrawerAndNonce,
            withdrawalStartBlock: uint32(block.number),
            delegatedAddress: address(0)
        });

        // Roll block number + 100k blocks into the future
        vm.roll(block.number + 100000);

        // Claim Withdrawal
        pufferVault.claimWithdrawalFromEigenLayer(queuedWithdrawal, tokens, 0);

        // 1 wei diff because of rounding
        assertApproxEqAbs(assetsBefore, pufferVault.totalAssets(), 1, "should remain the same after withdrawal");
    }

    function test_eigenlayer_cap_reached()
        public
        giveToken(BLAST_DEPOSIT, address(stETH), address(pufferVault), 1000 ether) // Blast got a lot of stETH
    {
        uint256 assetsBefore = pufferVault.totalAssets();

        // 1 wei diff because of rounding
        assertApproxEqAbs(assetsBefore, 1000 ether, 1, "should have 1k ether");

        vm.startPrank(COMMUNITY_MULTISIG);
        // EL Reverts
        vm.expectRevert("Pausable: index is paused");
        pufferVault.depositToEigenLayer(1000 ether);

        // 1 wei diff because of rounding
        assertApproxEqAbs(pufferVault.totalAssets(), 1000 ether, 1, "should have 1k ether after");
    }

    function _signPermit(_TestTemps memory t) internal pure returns (IPufferDepositor.Permit memory p) {
        bytes32 innerHash = keccak256(abi.encode(_PERMIT_TYPEHASH, t.owner, t.to, t.amount, t.nonce, t.deadline));
        bytes32 domainSeparator = t.domainSeparator;
        bytes32 outerHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, innerHash));
        (t.v, t.r, t.s) = vm.sign(t.privateKey, outerHash);

        return
            IPufferDepositor.Permit({ owner: t.owner, deadline: t.deadline, amount: t.amount, v: t.v, r: t.r, s: t.s });
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
