// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IDeposit {
    enum LotteryState {
        NOT_STARTED,
        ACTIVE,
        ENDED
    }

    function lotteryState() external view returns (LotteryState);

    function changeLotteryState(LotteryState _newState) external;

    function setWinner(address _winner) external;

    function buyerWithdraw() external;

    function sellerWithdraw() external;
}
