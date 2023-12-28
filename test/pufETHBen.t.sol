// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "openzeppelin/token/ERC20/IERC20.sol";
import { pufETHBen, IPuffETH } from "../src/pufETHBen.sol";
import { IStETH } from "../src/interface/IStETH.sol";
import { IEigenLayer } from "src/interface/IEigenLayer.sol";
import { IStrategy } from "src/interface/IEigenLayer.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PufETHTest is Test {
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

    // Token addresses
    address USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address APE = 0x4d224452801ACEd8B2F0aebE155379bb5D594381;

    function setUp() public {
        // 1 block after allowance increase for stETH on EL
        // https://etherscan.io/tx/0xc16610a3dc3e8732e3fbb7761f6e1c0e44869cba5a41b058d2b3abce98833667
        vm.createSelectFork(vm.rpcUrl("mainnet"), 18_814_788);

        pufETH = new pufETHBen(stETH, eigenStrategyManager);

        vm.label(address(stETH), "stETH proxy");
        vm.label(BINANCE, "BINANCE exchange");
        vm.label(0x93c4b944D05dfe6df7645A86cd2206016c51564D, "Eigen stETH strategy");

        (bob, bobSK) = makeAddrAndKey("bob");
    }

    // Transfer `token` from Binance to `to`
    modifier giveToken(address token, address to, uint256 amount) {
        vm.startPrank(BINANCE);
        SafeERC20.safeTransfer(IERC20(token), to, amount);
        vm.stopPrank();
        _;
    }

    modifier withCaller(address caller) {
        vm.startPrank(caller);
        _;
        vm.stopPrank();
    }

    function test_usdt_to_pufETH() public giveToken(USDT, alice, 2_000_000_000) withCaller(alice) {
        uint256 tokenInAmount = 2_000_000_000; // 2000 USDT

        // Manually edited the route code for USDT -> stETH
        // Last 20 bytes is the address of where the stETH is going
        // (0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f) is the address of pufETHBen
        bytes memory routeCode =
            hex"02dAC17F958D2ee523a2206206994597C13D831ec701ffff01c7bBeC68d12a0d1830360F8Ec58fA599bA1b0e9b004028DAAC072e492d34a3Afdbef0ba7e35D8b55C404C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2004028DAAC072e492d34a3Afdbef0ba7e35D8b55C4005615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f";

        assertEq(pufETH.balanceOf(alice), 0, "alice has 0 pufETH");

        // USDT doesn't have a permit, so the user needs to approve it to our contract
        SafeERC20.safeIncreaseAllowance(IERC20(USDT), address(pufETH), type(uint256).max);
        pufETH.swapAndDeposit({ amountIn: tokenInAmount, tokenIn: USDT, amountOutMin: 0, routeCode: routeCode });

        assertGt(pufETH.balanceOf(alice), 0, "alice has got pufETH");
    }

    function test_usdc_to_pufETH() public giveToken(USDC, dave, 20_000_000_000) withCaller(dave) {
        uint256 tokenInAmount = 20_000_000_000; // 20k USDC

        // Manually edited the route code for USDC -> stETH
        // Last 20 bytes is the address of where the stETH is going
        // (0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f) is the address of pufETHBen
        bytes memory routeCode =
            hex"02A0b86991c6218b36c1d19D4a2e9Eb0cE3606eB4801ffff0188e6A0c2dDD26FEEb64F039a2c41296FcB3f5640014028DAAC072e492d34a3Afdbef0ba7e35D8b55C404C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2004028DAAC072e492d34a3Afdbef0ba7e35D8b55C4005615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f";

        assertEq(pufETH.balanceOf(dave), 0, "dave has 0 pufETH");

        // USDT doesn't have a permit, so the user needs to approve it to our contract
        SafeERC20.safeIncreaseAllowance(IERC20(USDC), address(pufETH), type(uint256).max);
        pufETH.swapAndDeposit({ amountIn: tokenInAmount, tokenIn: USDC, amountOutMin: 0, routeCode: routeCode });

        assertGt(pufETH.balanceOf(dave), 0, "dave has got pufETH");
    }

    function test_ape_to_pufETH() public giveToken(APE, charlie, 1000 ether) withCaller(charlie) {
        uint256 tokenInAmount = 1000 ether; // 1000 APE

        // Manually edited the route code for APE -> stETH
        // Last 20 bytes is the address of where the stETH is going
        // (0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f) is the address of pufETHBen
        bytes memory routeCode =
            hex"024d224452801ACEd8B2F0aebE155379bb5D59438101ffff00130F4322e5838463ee460D5854F5D472cFC8f25301e43D6AAFce76f53670C4b7D6B38A7D8a67a4B67004C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc200e43D6AAFce76f53670C4b7D6B38A7D8a67a4B670005615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f";

        assertEq(pufETH.balanceOf(charlie), 0, "charlie has 0 pufETH");

        // USDT doesn't have a permit, so the user needs to approve it to our contract
        SafeERC20.safeIncreaseAllowance(IERC20(APE), address(pufETH), type(uint256).max);
        pufETH.swapAndDeposit({ amountIn: tokenInAmount, tokenIn: APE, amountOutMin: 0, routeCode: routeCode });

        assertGt(pufETH.balanceOf(charlie), 0, "charlie has got pufETH");
    }

    function test_usdc_to_pufETH_permit() public giveToken(USDC, bob, 10_000_000_000) withCaller(bob) {
        uint256 tokenInAmount = 10_000_000_000; // 20k USDC

        // To get the route code
        // Change tokenIn, and to if needed
        // https://swap.sushi.com/v3.2?chainId=1&tokenIn=0xF629cBd94d3791C9250152BD8dfBDF380E2a3B9c&tokenOut=0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84&amount=2000000000&maxPriceImpact=0.005&gasPrice=33538046487&to=0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f&preferSushi=false

        // Manually edited the route code for USDC -> stETH
        // Last 20 bytes is the address of where the stETH is going
        // (0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f) is the address of pufETHBen
        bytes memory routeCode =
            hex"02A0b86991c6218b36c1d19D4a2e9Eb0cE3606eB4801ffff0188e6A0c2dDD26FEEb64F039a2c41296FcB3f5640014028DAAC072e492d34a3Afdbef0ba7e35D8b55C404C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2004028DAAC072e492d34a3Afdbef0ba7e35D8b55C4005615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f";

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
