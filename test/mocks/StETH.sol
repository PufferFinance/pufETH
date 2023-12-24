// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.13;
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";
import {IStETH} from "../../src/interface/IStETH.sol";

interface ITestStETH is IStETH {
    function mintFor(address who, uint256 _sharesAmount) external;
}

contract StETH is ERC20, ITestStETH {
    constructor(uint256 initialSupply) ERC20("Lido's stETH", "stETH") {
        _mint(msg.sender, initialSupply);
    }

    function mintFor(address who, uint256 _sharesAmount) external {
        _mint(who, _sharesAmount);
    }

    function getPooledEthByShares(
        uint256 _sharesAmount
    ) external view returns (uint256) {
        // 1:1 stETH to pufETH
        return _sharesAmount;
    }

    function getSharesByPooledEth(
        uint256 _pooledEthAmount
    ) external view returns (uint256) {
        // 1:1 stETH to pufETH
        return _pooledEthAmount;
    }

    function submit(address _referral) external payable returns (uint256) {
        return 1 ether;
    }
}