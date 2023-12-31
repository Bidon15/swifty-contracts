// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Deposit} from "../src/Deposit.sol";
import {MockLottery} from "./MockLottery.sol";

contract DepositTest is Test {
    Deposit public deposit;
    MockLottery public mockLottery;

    uint256 private sellerPrivateKey = 0xa11ce;
    uint256 private multisigWalletPrivateKey = 0xb334d;
    uint256 private lotteryPrivateKey = 0xc56ef;

    address seller;
    address multisigWallet;
    address lottery;

    function setUp() public {
        // Generate addresses from private keys
        seller = vm.addr(sellerPrivateKey);
        multisigWallet = vm.addr(multisigWalletPrivateKey);
        lottery = vm.addr(lotteryPrivateKey);

        // Deploy the Deposit contract with the seller address
        deposit = new Deposit(seller);

        // Deploy the Mock Lottery contract
        mockLottery = new MockLottery();

        // Set up the contract addresses
        deposit.setLotteryAddress(lottery);
        mockLottery.setDepositAddress(address(deposit));

        // Set the multisig wallet address in the Deposit contract
        deposit.setMultisigWalletAddress(multisigWallet);
    }

    function test_DepositFunds() public {
        uint256 depositAmount = 1 ether;
        address user = address(3); // Example user address
        vm.deal(user, depositAmount); // Provide 1 ether to user

        vm.startPrank(user);
        deposit.deposit{value: depositAmount}();
        assertEq(deposit.deposits(user), depositAmount, "Deposit amount should be recorded correctly");
        vm.stopPrank();
    }

    function test_ChangeLotteryState() public {
        vm.prank(lottery);
        deposit.changeLotteryState(Deposit.LotteryState.ACTIVE);
        assertEq(
            uint256(deposit.lotteryState()), uint256(Deposit.LotteryState.ACTIVE), "Lottery state should be ACTIVE"
        );

        vm.prank(lottery);
        deposit.changeLotteryState(Deposit.LotteryState.ENDED);
        assertEq(uint256(deposit.lotteryState()), uint256(Deposit.LotteryState.ENDED), "Lottery state should be ENDED");
    }

    function test_NonWinnerWithdrawal() public {
        address nonWinner = address(4); // Example non-winner address
        uint256 depositAmount = 0.5 ether;
        vm.deal(nonWinner, depositAmount);

        // Non-winner deposits funds
        vm.startPrank(nonWinner);
        deposit.deposit{value: depositAmount}();
        vm.stopPrank();

        // End the lottery
        vm.prank(lottery);
        deposit.changeLotteryState(Deposit.LotteryState.ENDED);

        // Non-winner attempts to withdraw
        vm.startPrank(nonWinner);
        deposit.buyerWithdraw();
        assertEq(deposit.deposits(nonWinner), 0, "Non-winner should be able to withdraw their deposit");
        vm.stopPrank();
    }

    function test_MultipleUsersDeposit() public {
        address user1 = address(3);
        address user2 = address(4);
        uint256 user1Deposit = 0.5 ether;
        uint256 user2Deposit = 1 ether;

        vm.deal(user1, user1Deposit);
        vm.deal(user2, user2Deposit);

        vm.startPrank(user1);
        deposit.deposit{value: user1Deposit}();
        vm.stopPrank();

        vm.startPrank(user2);
        deposit.deposit{value: user2Deposit}();
        vm.stopPrank();

        assertEq(deposit.deposits(user1), user1Deposit, "User1 deposit should be recorded correctly");
        assertEq(deposit.deposits(user2), user2Deposit, "User2 deposit should be recorded correctly");
    }

    function test_SellerWithdrawalWithProtocolTax() public {
        address winner = address(3);
        uint256 winnerDeposit = 1 ether;
        uint256 protocolTax = (winnerDeposit * 5) / 100; // 5% tax
        uint256 amountToSeller = winnerDeposit - protocolTax;

        // Setup: Winner deposits and is set as a winner
        vm.deal(winner, winnerDeposit);
        vm.startPrank(winner);
        deposit.deposit{value: winnerDeposit}();
        vm.stopPrank();
        vm.prank(lottery);
        deposit.setWinner(winner);

        // End the lottery and process the withdrawal
        vm.prank(lottery);
        deposit.changeLotteryState(Deposit.LotteryState.ENDED);
        vm.prank(lottery);
        deposit.sellerWithdraw();

        // Check balances
        assertEq(address(multisigWallet).balance, protocolTax, "Multisig should receive the correct tax amount");
        assertEq(address(seller).balance, amountToSeller, "Seller should receive the correct amount after tax");
    }

    function test_WinnerCannotWithdraw() public {
        address winner = address(3);
        uint256 depositAmount = 1 ether;

        vm.deal(winner, depositAmount);
        vm.startPrank(winner);
        deposit.deposit{value: depositAmount}();
        vm.stopPrank();

        // Set as winner and try to withdraw
        vm.prank(lottery);
        deposit.setWinner(winner);
        vm.prank(lottery);
        deposit.changeLotteryState(Deposit.LotteryState.ENDED);
        vm.startPrank(winner);
        vm.expectRevert("Winners cannot withdraw");
        deposit.buyerWithdraw();
        vm.stopPrank();
    }

    function test_CompleteLotteryCycle() public {
        // Setup: Multiple participants deposit funds
        address[] memory participants = new address[](4);
        participants[0] = address(3);
        participants[1] = address(4);
        participants[2] = address(5);
        participants[3] = address(6);
        uint256 depositAmount = 1 ether;

        for (uint256 i = 0; i < participants.length; i++) {
            vm.deal(participants[i], depositAmount);
            vm.startPrank(participants[i]);
            deposit.deposit{value: depositAmount}();
            vm.stopPrank();
        }

        // End the lottery
        vm.prank(lottery);
        deposit.changeLotteryState(Deposit.LotteryState.ENDED);

        // Mark some participants as winners (e.g., first two)
        for (uint256 i = 0; i < 2; i++) {
            vm.prank(lottery);
            deposit.setWinner(participants[i]);
        }

        // Ensure winners cannot withdraw
        for (uint256 i = 0; i < 2; i++) {
            vm.startPrank(participants[i]);
            vm.expectRevert("Winners cannot withdraw");
            deposit.buyerWithdraw();
            vm.stopPrank();
        }

        // Ensure losers can withdraw
        for (uint256 i = 2; i < participants.length; i++) {
            uint256 initialBalance = participants[i].balance;
            vm.startPrank(participants[i]);
            deposit.buyerWithdraw();
            assertEq(participants[i].balance, initialBalance + depositAmount, "Loser should withdraw their deposit");
            vm.stopPrank();
        }

        // Test seller withdrawal and tax distribution
        uint256 totalPrizePool = depositAmount * 2; // Assuming 2 winners
        uint256 protocolTax = (totalPrizePool * 5) / 100;
        uint256 amountToSeller = totalPrizePool - protocolTax;
        uint256 initialSellerBalance = seller.balance;
        uint256 initialMultisigBalance = multisigWallet.balance;

        vm.prank(lottery);
        deposit.sellerWithdraw();

        assertEq(
            seller.balance, initialSellerBalance + amountToSeller, "Seller should receive correct amount after tax"
        );
        assertEq(multisigWallet.balance, initialMultisigBalance + protocolTax, "Multisig should receive the tax amount");
    }

    function test_EdgeCaseDeposits() public {
        address user = address(3);
        uint256 depositAmount = 1 ether;

        // Setup: Provide Ether to the user
        vm.deal(user, depositAmount);

        // Case 1: Deposit right before the lottery starts
        vm.startPrank(user);
        deposit.deposit{value: depositAmount}();
        vm.stopPrank();
        assertEq(deposit.deposits(user), depositAmount, "Deposit before start should be recorded");

        // Start the lottery
        vm.prank(lottery);
        deposit.changeLotteryState(Deposit.LotteryState.ACTIVE);

        // End the lottery to allow withdrawal
        vm.prank(lottery);
        deposit.changeLotteryState(Deposit.LotteryState.ENDED);

        // Case 2: Attempt to withdraw multiple times
        vm.startPrank(user);
        deposit.buyerWithdraw();
        assertEq(deposit.deposits(user), 0, "User should have withdrawn their deposit");
        vm.expectRevert("No funds to withdraw");
        deposit.buyerWithdraw(); // Attempt to withdraw again
        vm.stopPrank();

        // Case 3: Deposit right after the lottery ends
        vm.deal(user, depositAmount);
        vm.startPrank(user);
        deposit.deposit{value: depositAmount}();
        vm.stopPrank();
        assertEq(deposit.deposits(user), depositAmount, "Deposit after end should be recorded");
    }
}
