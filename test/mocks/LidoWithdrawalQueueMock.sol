// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import { ILidoWithdrawalQueue } from "src/interface/Lido/ILidoWithdrawalQueue.sol";

contract LidoWithdrawalQueueMock is ILidoWithdrawalQueue {
    function requestWithdrawals(uint256[] calldata _amounts, address _owner)
        external
        returns (uint256[] memory requestIds)
    { }

    function claimWithdrawal(uint256 _requestId) external { }
}
