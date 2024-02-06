// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract Deposit is Ownable {
    enum LotteryState {
        NOT_STARTED,
        ACTIVE,
        ENDED
    }

    LotteryState public lotteryState;

    address public multisigWalletAddress;
    address public seller;

    uint256 public minimumDepositAmount;
    uint256 public numberOfTickets;
    address[] private eligibleParticipants;
    mapping(address => bool) public hasMinted;

    mapping(address => uint256) public deposits;
    mapping(address => bool) public winners;
    address[] public winnerAddresses;
    address[] private participants;

    event LotteryStarted();
    event WinnerSelected(address indexed winner);
    event LotteryEnded();

    modifier onlySeller() {
        require(msg.sender == seller, "Only seller can call this function");
        _;
    }

    modifier lotteryNotStarted() {
        require(lotteryState == LotteryState.NOT_STARTED, "Lottery is in active state");
        _;
    }

    modifier lotteryStarted() {
        require(lotteryState == LotteryState.ACTIVE, "Lottery is not active");
        _;
    }

    modifier lotteryEnded() {
        require(lotteryState == LotteryState.ENDED, "Lottery is not ended yet");
        _;
    }

    modifier hasNotMinted() {
        require(!hasMinted[msg.sender], "NFT already minted");
        _;
    }

    modifier whenLotteryNotActive() {
        require(lotteryState != LotteryState.ACTIVE, "Lottery is currently active");
        _;
    }

    constructor(address _seller) {
        seller = _seller;
    }

    function deposit() public payable whenLotteryNotActive {
        require(msg.value > 0, "No funds sent");
        if (deposits[msg.sender] == 0) {
            participants.push(msg.sender);
        }

        deposits[msg.sender] += msg.value;
    }

    function getParticipants() public view returns (address[] memory) {
        return participants;
    }

    function setMultisigWalletAddress(address _multisigWalletAddress) public onlyOwner {
        multisigWalletAddress = _multisigWalletAddress;
    }

    function changeLotteryState(LotteryState _newState) internal {
        lotteryState = _newState;
    }

    function isWinner(address _participant) public view returns (bool) {
        return winners[_participant];
    }

    function getWinners() public view returns (address[] memory) {
        return winnerAddresses;
    }

    function setWinner(address _winner) internal {
        winners[_winner] = true;
        winnerAddresses.push(_winner);
    }

    function buyerWithdraw() public whenLotteryNotActive {
        require(!winners[msg.sender], "Winners cannot withdraw");

        uint256 amount = deposits[msg.sender];
        require(amount > 0, "No funds to withdraw");

        deposits[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    }

    function sellerWithdraw() public onlySeller() {
        require(lotteryState == LotteryState.ENDED, "Lottery not ended");

        uint256 totalAmount = 0;

        for (uint256 i = 0; i < winnerAddresses.length; i++) {
            address winner = winnerAddresses[i];
            totalAmount += deposits[winner];
            deposits[winner] = 0; // Prevent double withdrawal
        }

        uint256 protocolTax = (totalAmount * 5) / 100; // 5% tax
        uint256 amountToSeller = totalAmount - protocolTax;

        payable(multisigWalletAddress).transfer(protocolTax);
        payable(seller).transfer(amountToSeller);
    }


    function _fulfillRandomness(uint256 randomness, uint256, bytes memory extraData) internal override {
        require(lotteryState == LotteryState.ACTIVE, "Lottery is not active");
        require(numberOfTickets > 0, "No tickets left to allocate");

        address sellerAddress = abi.decode(extraData, (address));

        // You can now use sellerAddress for verification or tracking
        require(sellerAddress == msg.sender, "Only the original seller can fulfill randomness");

        uint256 randomIndex = randomness % eligibleParticipants.length;
        address selectedWinner = eligibleParticipants[randomIndex];

        if (!isWinner(selectedWinner)) {
            setWinner(selectedWinner);
            removeParticipant(randomIndex);
            numberOfTickets--;

            // Emit an event each time a winner is selected
            emit WinnerSelected(selectedWinner);

            // If there are still tickets left, you can request more randomness for the next winner
            if (numberOfTickets == 0) {
                emit LotteryEnded();
            }
        }
    }

        function initiateSelectWinner() public onlySeller lotteryStarted {
        require(numberOfTickets > 0, "All tickets have been allocated");
        require(eligibleParticipants.length > 0, "No eligible participants left");

        // Use the seller's address as extraData
        bytes memory extraData = abi.encode(msg.sender);

        // Request randomness from Gelato's VRF with the seller's address as extraData
        _requestRandomness(extraData);

        // Optionally, you can emit an event here if you want to signal that the selection process has started
        // emit LotterySelectionInitiated();
    }

    function setMinimumDepositAmount(uint256 _amount) public onlySeller {
        minimumDepositAmount = _amount;
    }

        function setNumberOfTickets(uint256 _numberOfTickets) public onlySeller {
        require(_numberOfTickets > 0, "Number of tickets must be greater than zero");
        numberOfTickets = _numberOfTickets;
    }

    function startLottery() public onlySeller lotteryNotStarted {
        changeLotteryState(LotteryState.ACTIVE);
        checkEligibleParticipants();
    }

    function endLottery() public onlySeller lotteryStarted {
        changeLotteryState(LotteryState.ENDED);
        // Additional logic for ending the lottery
        // Process winners, mint NFT tickets, etc.
    }

    function getDepositedAmount(address participant) external view returns (uint256) {
        return deposits[participant];
    }

    // Function to check and mark eligible participants
    function checkEligibleParticipants() internal {
        for (uint256 i = 0; i < participants.length; i++) {
            uint256 depositedAmount = deposits[participants[i]];
            if (depositedAmount >= minimumDepositAmount) {
                // Mark this participant as eligible for the lottery
                eligibleParticipants.push(participants[i]);
            }
        }
    }

    function removeParticipant(uint256 index) internal {
        require(index < eligibleParticipants.length, "Index out of bounds");

        // If the winner is not the last element, swap it with the last element
        if (index < eligibleParticipants.length - 1) {
            eligibleParticipants[index] = eligibleParticipants[eligibleParticipants.length - 1];
        }

        // Remove the last element (now the winner)
        eligibleParticipants.pop();
    }

    function isParticipantEligible(address participant) public view returns (bool) {
        for (uint256 i = 0; i < eligibleParticipants.length; i++) {
            if (eligibleParticipants[i] == participant) {
                return true;
            }
        }
        return false;
    }
}
