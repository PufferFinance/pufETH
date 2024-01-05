// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { pufETHBen, IPuffETH } from "../src/pufETHBen.sol";
import { IStETH } from "../src/interface/IStETH.sol";
import { IEigenLayer } from "src/interface/IEigenLayer.sol";
import { IStrategy } from "src/interface/IEigenLayer.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { DeployPuffer } from "script/DeployPuffer.s.sol";
import { PufferDeployment } from "src/structs/PufferDeployment.sol";
import { stdStorage, StdStorage } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { LidoVault } from "src/LidoVault.sol";

contract PufETHTest is Test {
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

    pufETHBen public pufETH;
    LidoVault public lidoVault;

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

    // We are taking CZ's money
    address BINANCE = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
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

    function setUp() public {
        // 1 block after allowance increase for stETH on EL
        // https://etherscan.io/tx/0xc16610a3dc3e8732e3fbb7761f6e1c0e44869cba5a41b058d2b3abce98833667
        // vm.createSelectFork(vm.rpcUrl("mainnet"), 18_814_788);
        vm.createSelectFork(vm.rpcUrl("mainnet"), 18812842);

        PufferDeployment memory deployment = new DeployPuffer().run();
        pufETH = pufETHBen(payable(deployment.pufETH));
        lidoVault = pufETHBen(payable(deployment.pufETH))._LIDO_VAULT();

        vm.label(address(stETH), "stETH");
        vm.label(BINANCE, "BINANCE exchange");
        vm.label(0x93c4b944D05dfe6df7645A86cd2206016c51564D, "Eigen stETH strategy");

        (bob, bobSK) = makeAddrAndKey("bob");
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

    function rebaseLido() internal {
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

    function _finalizeWithdrawals(uint256 requestIdFinalized) internal {
        // Alter WithdrawalRouter storage slot to mark our withdrawal requests as finalized
        vm.store(
            LIDO_WITHDRAWAL_QUEUE,
            keccak256("lido.WithdrawalQueue.lastFinalizedRequestId"),
            bytes32(uint256(requestIdFinalized))
        );
    }

    function test_minting_and_lido_rebasing()
        public
        giveToken(BLAST_DEPOSIT, address(stETH), alice, 1000 ether) // Blast got a lot of stETH
        giveToken(BLAST_DEPOSIT, address(stETH), bob, 1000 ether)
    {
        // Pretend that alice is depositing 1k ETH
        vm.startPrank(alice);
        SafeERC20.safeIncreaseAllowance(IERC20(stETH), address(pufETH), type(uint256).max);

        uint256 aliceMinted = pufETH.depositStETH(1000 ether);

        // Save total ETH backing before the rebase
        uint256 backingETHAmountBefore = lidoVault.getTotalBackingEthAmount();

        // Check the balance before rebase
        uint256 stethBalanceBefore = IERC20(stETH).balanceOf(address(lidoVault));

        rebaseLido();

        // Check the balance after rebase and assert that it increased
        uint256 stethBalanceAfter = IERC20(stETH).balanceOf(address(lidoVault));

        assertTrue(stethBalanceAfter > stethBalanceBefore, "lido rebase failed");

        // After rebase, Bob is depositing 1k ETH
        vm.startPrank(bob);
        SafeERC20.safeIncreaseAllowance(IERC20(stETH), address(pufETH), type(uint256).max);
        uint256 bobMinted = pufETH.depositStETH(1000 ether);

        // Alice should have more pufETH because the rebase happened after her deposit and changed the rate
        assertTrue(aliceMinted > bobMinted, "alice should have more");

        // ETH Backing after rebase should go up
        assertTrue(lidoVault.getTotalBackingEthAmount() > backingETHAmountBefore, "eth backing went down");
    }

    function test_depositingStETH_and_withdrawal() public {
        test_minting_and_lido_rebasing();

        // Check the balance of our vault
        uint256 balance = stETH.balanceOf(address(address(lidoVault)));

        // We deposited 2k ETH, but because of the rebase we have more than 2k
        //
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 1000 ether; // steth Amount
        amounts[1] = 1000 ether; // steth Amount
        amounts[2] = balance - 2000 ether; // the test

        // Initiate Withdrawals from lido
        uint256[] memory requestIds = lidoVault.initiateETHWithdrawals(amounts);

        // Finalize them and fast forward to +10 days
        _finalizeWithdrawals(requestIds[2]);
        vm.roll(block.number + 10 days); // stupid bug

        // Claim withdrawals
        lidoVault.claimWithdrawals(requestIds);

        // Assert that we got more ETH than our original 2k ETH
        assertGt(address(lidoVault).balance, 2000 ether, "oh no");
    }

    function test_minting_and_rebasing()
        public
        giveToken(BLAST_DEPOSIT, address(stETH), alice, 150 ether)
        withCaller(alice)
    {
        uint256 valueBefore = uint256(vm.load(address(stETH), CL_BALANCE_POSITION));
        assertEq(valueBefore, 9144378430694263000000000); // ~ 9144378 ETH

        // User needs to get the same amount back when depositing the same amount
        // 1 ETH worth of stETH should mint x pufETH === 1 ETH to pufferPool should mint x pufETH
        SafeERC20.safeIncreaseAllowance(IERC20(stETH), address(pufETH), type(uint256).max);

        // Total Pooled ETH in Lido on this block number is 9167717154712566954985730 ~ 9167717.154 ETH
        // Lido gets ~ 9532 ETH in daily rewards on consensus layer
        // Here are two oracle updates
        // https://etherscan.io/tx/0xbc986580ef6f425cc4758d58c9c6b3510baef86331097b5d64f27825257415ac
        // https://etherscan.io/tx/0x06a828d3b5aaed2decd9fe105ac6a08a81c2a1cc62a12c01be418755ea3e8ba8

        uint256 mintedBeforeRebase = pufETH.depositStETH(10 ether);
        assertApproxEqAbs(mintedBeforeRebase, 10 ether, 5, "bad amount minted");

        uint256 backingETHAmount = lidoVault.getTotalBackingEthAmount();
        assertApproxEqAbs(backingETHAmount, 10 ether, 5, "backing amount should be ~10 eth with 5 wei mistake");

        uint256 ethBefore = stETH.getTotalPooledEther();

        uint256 ethBeforeAfter = stETH.getTotalPooledEther();

        assertApproxEqRel(ethBefore, ethBeforeAfter, 0.5e18, "after should be 5% diff");

        uint256 mintedAfterRebase = pufETH.depositStETH(10 ether);

        assertApproxEqRel(mintedAfterRebase, 10 ether, 0.5e18, "bad amount minted 2");

        // We should have more than we deposited
        uint256 backingETHAmountAfter = lidoVault.getTotalBackingEthAmount();

        assertApproxEqAbs(backingETHAmountAfter, 20.5 ether, 5, "backing amount should be ~20 eth with 5 wei mistake");

        // _rebaseLido(valueBefore + 10000 ether); // simulate a good day for Lido + 10k ETH
    }

    function test_usdt_to_pufETH() public giveToken(BINANCE, USDT, alice, 2_175_000_000) withCaller(alice) {
        uint256 tokenInAmount = 2_175_000_000; // 2100 USDT

        // Manually edited the route code for USDT -> stETH
        // Last 20 bytes is the address of where the stETH is going
        // (0xf034A0Cca1cE58fb2d234438D4d40227635ef771) is the address of pufETHBen
        bytes memory routeCode =
            hex"02dAC17F958D2ee523a2206206994597C13D831ec701ffff01c7bBeC68d12a0d1830360F8Ec58fA599bA1b0e9b004028DAAC072e492d34a3Afdbef0ba7e35D8b55C404C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2004028DAAC072e492d34a3Afdbef0ba7e35D8b55C400f034A0Cca1cE58fb2d234438D4d40227635ef771";

        assertEq(pufETH.balanceOf(alice), 0, "alice has 0 pufETH");

        // USDT doesn't have a permit, so the user needs to approve it to our contract
        SafeERC20.safeIncreaseAllowance(IERC20(USDT), address(pufETH), type(uint256).max);
        pufETH.swapAndDeposit({ amountIn: tokenInAmount, tokenIn: USDT, amountOutMin: 0, routeCode: routeCode });

        uint256 shares = stETH.sharesOf(address(pufETH));
        uint256 ethAmount = pufETH.getpufETHByStETH(pufETH.balanceOf(address(alice)));

        assertGt(pufETH.balanceOf(alice), 0, "alice has got pufETH");
        assertGt(stETH.balanceOf(address(pufETH)), 0, "pufETH should hold stETH");
    }

    function test_usdc_to_pufETH() public giveToken(BINANCE, USDC, dave, 20_000_000_000) withCaller(dave) {
        uint256 tokenInAmount = 20_000_000_000; // 20k USDC

        // Manually edited the route code for USDC -> stETH
        // Last 20 bytes is the address of where the stETH is going
        // (0xf034A0Cca1cE58fb2d234438D4d40227635ef771) is the address of pufETHBen
        bytes memory routeCode =
            hex"02A0b86991c6218b36c1d19D4a2e9Eb0cE3606eB4801ffff0188e6A0c2dDD26FEEb64F039a2c41296FcB3f5640014028DAAC072e492d34a3Afdbef0ba7e35D8b55C404C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2004028DAAC072e492d34a3Afdbef0ba7e35D8b55C400f034A0Cca1cE58fb2d234438D4d40227635ef771";

        assertEq(pufETH.balanceOf(dave), 0, "dave has 0 pufETH");

        // USDT doesn't have a permit, so the user needs to approve it to our contract
        SafeERC20.safeIncreaseAllowance(IERC20(USDC), address(pufETH), type(uint256).max);
        pufETH.swapAndDeposit({ amountIn: tokenInAmount, tokenIn: USDC, amountOutMin: 0, routeCode: routeCode });

        assertGt(pufETH.balanceOf(dave), 0, "dave has got pufETH");
    }

    function test_ape_to_pufETH() public giveToken(BINANCE, APE, charlie, 1000 ether) withCaller(charlie) {
        uint256 tokenInAmount = 1000 ether; // 1000 APE

        // Manually edited the route code for APE -> stETH
        // Last 20 bytes is the address of where the stETH is going
        // (0xf034A0Cca1cE58fb2d234438D4d40227635ef771) is the address of pufETHBen
        bytes memory routeCode =
            hex"024d224452801ACEd8B2F0aebE155379bb5D59438101ffff00130F4322e5838463ee460D5854F5D472cFC8f25301e43D6AAFce76f53670C4b7D6B38A7D8a67a4B67004C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc200e43D6AAFce76f53670C4b7D6B38A7D8a67a4B67000f034A0Cca1cE58fb2d234438D4d40227635ef771";

        assertEq(pufETH.balanceOf(charlie), 0, "charlie has 0 pufETH");

        // USDT doesn't have a permit, so the user needs to approve it to our contract
        SafeERC20.safeIncreaseAllowance(IERC20(APE), address(pufETH), type(uint256).max);
        pufETH.swapAndDeposit({ amountIn: tokenInAmount, tokenIn: APE, amountOutMin: 0, routeCode: routeCode });

        assertGt(pufETH.balanceOf(charlie), 0, "charlie has got pufETH");
    }

    function test_usdc_to_pufETH_permit() public giveToken(BINANCE, USDC, bob, 10_000_000_000) withCaller(bob) {
        uint256 tokenInAmount = 10_000_000_000; // 20k USDC

        // To get the route code
        // Change tokenIn, and to if needed
        // https://swap.sushi.com/v3.2?chainId=1&tokenIn=0xF629cBd94d3791C9250152BD8dfBDF380E2a3B9c&tokenOut=0xf034A0Cca1cE58fb2d234438D4d40227635ef771&amount=2000000000&maxPriceImpact=0.005&gasPrice=33538046487&to=0xf034A0Cca1cE58fb2d234438D4d40227635ef771&preferSushi=false

        // Manually edited the route code for USDC -> stETH
        // Last 20 bytes is the address of where the stETH is going
        // (0xf034A0Cca1cE58fb2d234438D4d40227635ef771) is the address of pufETHBen
        bytes memory routeCode =
            hex"02A0b86991c6218b36c1d19D4a2e9Eb0cE3606eB4801ffff0188e6A0c2dDD26FEEb64F039a2c41296FcB3f5640014028DAAC072e492d34a3Afdbef0ba7e35D8b55C404C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2004028DAAC072e492d34a3Afdbef0ba7e35D8b55C400f034A0Cca1cE58fb2d234438D4d40227635ef771";

        assertEq(pufETH.balanceOf(bob), 0, "bob has 0 pufETH");

        IPuffETH.Permit memory permit = _signPermit(
            _testTemps(
                "bob",
                address(pufETH),
                tokenInAmount,
                block.timestamp,
                hex"06c37168a7db5138defc7866392bb87a741f9b3d104deb5094588ce041cae335"
            )
        );

        // USDT doesn't have a permit, so the user needs to approve it to our contract
        pufETH.swapAndDepositWithPermit({ tokenIn: USDC, amountOutMin: 0, permitData: permit, routeCode: routeCode });

        assertGt(pufETH.balanceOf(bob), 0, "bob has got pufETH");
    }

    function test_conversions_and_deposit_to_el() public {
        test_ape_to_pufETH();
        test_usdc_to_pufETH();
        test_usdc_to_pufETH_permit();
        test_usdt_to_pufETH();

        pufETH.depositToEigenLayer(stETH.balanceOf(address(pufETH)));

        (, uint256[] memory amounts) = eigenStrategyManager.getDeposits(address(pufETH));

        for (uint256 i = 0; i < amounts.length; ++i) {
            if (amounts[i] != 0) {
                // If we have some amount somewhere, we deposited
                return;
            }
        }

        assertTrue(false, "no deposit to EL");
    }

    function _signPermit(_TestTemps memory t) internal pure returns (IPuffETH.Permit memory p) {
        bytes32 innerHash = keccak256(abi.encode(_PERMIT_TYPEHASH, t.owner, t.to, t.amount, t.nonce, t.deadline));
        bytes32 domainSeparator = t.domainSeparator;
        bytes32 outerHash = keccak256(abi.encodePacked("\x19\x01", domainSeparator, innerHash));
        (t.v, t.r, t.s) = vm.sign(t.privateKey, outerHash);

        return IPuffETH.Permit({ owner: t.owner, deadline: t.deadline, amount: t.amount, v: t.v, r: t.r, s: t.s });
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
