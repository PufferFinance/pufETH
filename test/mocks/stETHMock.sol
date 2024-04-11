// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "../../src/interface/Lido/IStETH.sol";

contract stETHMock is IStETH, ERC20, ERC20Burnable {
    constructor() ERC20("Mock stETH", "mockStETH") { }

    uint256 public totalShares;
    uint256 public totalPooledEther;

    function mint(address to, uint256 value) external {
        _mint(to, value);
    }

    function burn(address from, uint256 value) external {
        _burn(from, value);
    }

    function slash(address holder, uint256 amount) public {
        _burn(holder, amount);
    }

    function submit(address /*referral*/ ) external payable returns (uint256) {
        uint256 sharesToMint = getSharesByPooledEth(msg.value);
        _mint(msg.sender, sharesToMint);
        return sharesToMint;
    }

    function setTotalShares(uint256 _totalShares) public {
        totalShares = _totalShares;
    }

    function setTotalPooledEther(uint256 _totalPooledEther) public {
        totalPooledEther = _totalPooledEther;
    }

    function getTotalPooledEther() external view returns (uint256) {
        return totalPooledEther;
    }

    function sharesOf(address _account) external view returns (uint256) {
        //not implemented, just there for IstETH conformance
    }

    function transferSharesFrom(address _sender, address _recipient, uint256 _sharesAmount)
        external
        returns (uint256)
    { }

    function transferShares(address _recipient, uint256 _sharesAmount) external returns (uint256) {
        //not implemented, just there for IstETH conformance
    }

    function getPooledEthByShares(uint256 _sharesAmount) public view returns (uint256) {
        if (totalShares == 0) {
            return 0;
        }
        return _sharesAmount * totalPooledEther / totalShares;
    }

    function getSharesByPooledEth(uint256 _pooledEthAmount) public view returns (uint256) {
        if (totalPooledEther == 0) {
            return 0;
        }
        return _pooledEthAmount * totalShares / totalPooledEther;
    }

    function totalSupply() public view override(ERC20, IStETH) returns (uint256) {
        return super.totalSupply();
    }
}
