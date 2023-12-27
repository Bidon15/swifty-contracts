// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/NFTLotteryTicket.sol";
import "./MockDeposit.sol";

contract NFTLotteryTicketTest is Test {
    NFTLotteryTicket private nftLotteryTicket;
    MockDeposit private mockDeposit;

    function setUp() public {
        // Deploy the MockDeposit and NFTLotteryTicket contracts
        mockDeposit = new MockDeposit();
        nftLotteryTicket = new NFTLotteryTicket("ipfs://example_uri/");

        // Set the MockDeposit contract address in NFTLotteryTicket
        nftLotteryTicket.setDepositContract(address(mockDeposit));
    }

    function testInitialLotteryState() public {
        // Verify that the lottery state is initially NOT_STARTED
        assertEq(uint256(nftLotteryTicket.lotteryState()), uint256(IDeposit.LotteryState.NOT_STARTED));
    }

    function testStartLottery() public {
        // Start the lottery
        nftLotteryTicket.startLottery();

        // Verify that the lottery state has changed to ACTIVE
        assertEq(uint256(nftLotteryTicket.lotteryState()), uint256(IDeposit.LotteryState.ACTIVE));
    }

    function testEligibilityCheck() public {
        // Simulate deposit amounts in MockDeposit
        address participant1 = address(1);
        address participant2 = address(2);
        uint256 eligibleAmount = 100; // Assume 100 is the minimum deposit amount for eligibility
        nftLotteryTicket.setMinimumDepositAmount(eligibleAmount);
        mockDeposit.setDepositedAmount(participant1, eligibleAmount);
        mockDeposit.setDepositedAmount(participant2, eligibleAmount / 2); // Ineligible amount

        // Start the lottery, which should also check eligibility
        nftLotteryTicket.startLottery();

        // Check if participant1 is marked eligible
        bool isParticipant1Eligible = nftLotteryTicket.isParticipantEligible(participant1);
        assertTrue(isParticipant1Eligible);

        // Check if participant2 is not marked eligible
        bool isParticipant2Eligible = nftLotteryTicket.isParticipantEligible(participant2);
        assertFalse(isParticipant2Eligible);
    }

    function testEndLottery() public {
        // Setup: Start the lottery first
        nftLotteryTicket.startLottery();

        // End the lottery
        nftLotteryTicket.endLottery();

        // Verify that the lottery state has changed to ENDED
        assertEq(uint256(nftLotteryTicket.lotteryState()), uint256(IDeposit.LotteryState.ENDED));
    }

    function testInvalidActions() public {
        // Attempt to start the lottery when it's already active
        nftLotteryTicket.startLottery();
        vm.expectRevert("Lottery is in active state");
        nftLotteryTicket.startLottery();

        nftLotteryTicket.endLottery();
        // Attempt to end the lottery when it's not started
        vm.expectRevert("Lottery is not active");
        nftLotteryTicket.endLottery();

        // Attempt to mint NFT as a non-winner
        address nonWinner = address(2); // Assuming address(2) is not a winner
        vm.prank(nonWinner);
        vm.expectRevert("Caller is not a winner");
        nftLotteryTicket.mintMyNFT(1);
    }

    // Additional test cases can be added here
}
