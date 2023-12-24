// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;
import {IStETHVault} from "../../src/interface/IStETHVault.sol";
import {IStETH} from "../../src/interface/IStETH.sol";
import {IEigenLayer} from "../../src/interface/IEigenLayer.sol";


contract StETHVault is IStETHVault {
    uint256 MAX_APPROVAL = ~uint256(0);
    IEigenLayer public constant EIGENLAYER =
        IEigenLayer(0xdAC17F958D2ee523a2206206994597C13D831ec7); // todo

    IStETH public constant stETH =
        IStETH(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);

    constructor() public {
        stETH.approve(address(EIGENLAYER), MAX_APPROVAL);
    }

    // Deposit stETH for EigenPoints
    function depositToEigenLayer(uint256 amount) external returns (uint256) {
        return EIGENLAYER.depositStETH(amount);
    }
}