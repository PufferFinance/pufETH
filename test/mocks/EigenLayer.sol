// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;
import {IEigenLayer} from "../../src/interface/IEigenLayer.sol";
import {IStETH} from "../../src/interface/IStETH.sol";

contract EigenLayer is IEigenLayer {
    IStETH public constant stETH =
        IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    function depositStETH(uint256 _stETHAmount) external returns (uint256) {
        stETH.transferFrom(msg.sender, address(this), _stETHAmount);
        return _stETHAmount;
    }
}