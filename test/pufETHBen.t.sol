// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console2 } from "forge-std/Test.sol";
import { pufETHBen } from "../src/pufETHBen.sol";
import { IStETH } from "../src/interface/IStETH.sol";

contract PufETHTest is Test {
    pufETHBen public pufETH;

    IStETH stETH = IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    function setUp() public {
        vm.createSelectFork(vm.rpcUrl("mainnet"), 18_875_624);
        pufETH = new pufETHBen(stETH);
        vm.deal(address(this), 100 ether);
    }

    function test_Name_ShouldDoSomething_WhenSomethingHappens() public {
        vm.deal(address(this), stETH, 10 ether);
        pufETH.wrap();
    }
}
