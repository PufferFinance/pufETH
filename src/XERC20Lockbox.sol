// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.9.0;

import { IXERC20 } from "./interface/IXERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { IXERC20Lockbox } from "./interface/IXERC20Lockbox.sol";

contract XERC20Lockbox is IXERC20Lockbox {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    /**
     * @notice The XERC20 token of this contract
     */
    IXERC20 public immutable XERC20;

    /**
     * @notice The ERC20 token of this contract
     */
    IERC20 public immutable ERC20;

    /**
     * @notice Constructor
     *
     * @param xerc20 The address of the XERC20 contract
     * @param erc20 The address of the ERC20 contract
     */
    constructor(address xerc20, address erc20) {
        XERC20 = IXERC20(xerc20);
        ERC20 = IERC20(erc20);
    }

    /**
     * @notice Deposit ERC20 tokens into the lockbox
     *
     * @param amount The amount of tokens to deposit
     */
    function deposit(uint256 amount) external {
        _deposit(msg.sender, amount);
    }

    /**
     * @notice Deposit ERC20 tokens into the lockbox, and send the XERC20 to a user
     *
     * @param to The user to send the XERC20 to
     * @param amount The amount of tokens to deposit
     */
    function depositTo(address to, uint256 amount) external {
        _deposit(to, amount);
    }

    /**
     * @notice Not a native asset
     */
    function depositNativeTo(address) public payable {
        revert IXERC20Lockbox_NotNative();
    }

    /**
     * @notice Deposit native tokens into the lockbox
     */
    function depositNative() public payable {
        revert IXERC20Lockbox_NotNative();
    }

    /**
     * @notice Withdraw ERC20 tokens from the lockbox
     *
     * @param amount The amount of tokens to withdraw
     */
    function withdraw(uint256 amount) external {
        _withdraw(msg.sender, amount);
    }

    /**
     * @notice Withdraw tokens from the lockbox
     *
     * @param to The user to withdraw to
     * @param amount The amount of tokens to withdraw
     */
    function withdrawTo(address to, uint256 amount) external {
        _withdraw(to, amount);
    }

    /**
     * @notice Withdraw tokens from the lockbox
     *
     * @param to The user to withdraw to
     * @param amount The amount of tokens to withdraw
     */
    function _withdraw(address to, uint256 amount) internal {
        emit Withdraw(to, amount);

        XERC20.burn(msg.sender, amount);
        ERC20.safeTransfer(to, amount);
    }

    /**
     * @notice Deposit tokens into the lockbox
     *
     * @param to The address to send the XERC20 to
     * @param amount The amount of tokens to deposit
     */
    function _deposit(address to, uint256 amount) internal {
        ERC20.safeTransferFrom(msg.sender, address(this), amount);
        XERC20.mint(to, amount);

        emit Deposit(to, amount);
    }

    /**
     * @notice Fallback function to deposit native tokens
     */
    receive() external payable {
        depositNative();
    }
}
