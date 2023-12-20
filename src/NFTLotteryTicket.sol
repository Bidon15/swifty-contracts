// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./interfaces/IDeposit.sol";

contract NFTLotteryTicket is ERC1155 {
    uint256 public constant TOKEN_ID = 1;

    address public seller;
    IDeposit public depositContract;
    IDeposit.LotteryState public lotteryState;
    uint256 public minimumDepositAmount;

    // TODO: Do we actually need to clear this array?
    // If yes, then we need to add a function to clear this array
    // after the lottery is ended
    // If we do 'fire n forget' minting, then we don't need to clear this array
    // and provide a good UX/UI that sellers need to redeploy
    // which will make this a template contract so to speak
    address[] private eligibleParticipants;
    uint256 public numberOfTickets;
    mapping(address => bool) public hasMinted;

    constructor(string memory uri) ERC1155(uri) {
        seller = msg.sender;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Only seller can call this function");
        _;
    }

    modifier lotteryNotStarted() {
        require(lotteryState == IDeposit.LotteryState.NOT_STARTED, "Lottery is in active state");
        _;
    }

    modifier lotteryStarted() {
        require(lotteryState == IDeposit.LotteryState.ACTIVE, "Lottery is not active");
        _;
    }

    modifier lotteryEnded() {
        require(lotteryState == IDeposit.LotteryState.ENDED, "Lottery is not ended yet");
        _;
    }

    modifier isWinner() {
        require(depositContract.isWinner(msg.sender), "Caller is not a winner");
        _;
    }

    modifier hasNotMinted() {
        require(!hasMinted[msg.sender], "NFT already minted");
        _;
    }

    modifier validTokenId(uint256 _tokenId) {
        require(_tokenId == TOKEN_ID, "Invalid token ID");
        _;
    }

    // Private function for random number generation
    // TODO: Replace with VRF logic and callback based
    function _getRandomNumber(uint256 seed, uint256 max) private view returns (uint256) {
        // Placeholder for basic pseudo-random generation; to be replaced with VRF logic
        return uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, seed))) % max;
    }

    function setMinimumDepositAmount(uint256 _amount) public onlySeller {
        minimumDepositAmount = _amount;
    }

    function setNumberOfTickets(uint256 _numberOfTickets) public onlySeller {
        require(_numberOfTickets > 0, "Number of tickets must be greater than zero");
        numberOfTickets = _numberOfTickets;
    }

    function setDepositContract(address _depositContractAddress) public onlySeller {
        depositContract = IDeposit(_depositContractAddress);
    }

    function startLottery() public onlySeller lotteryNotStarted {
        lotteryState = IDeposit.LotteryState.ACTIVE;
        depositContract.changeLotteryState(IDeposit.LotteryState.ACTIVE);
        // Additional logic for starting the lottery
        // Check eligible participants, etc.
        checkEligibleParticipants();
    }

    function endLottery() public onlySeller lotteryStarted {
        lotteryState = IDeposit.LotteryState.ENDED;
        depositContract.changeLotteryState(IDeposit.LotteryState.ENDED);
        // Additional logic for ending the lottery
        // Process winners, mint NFT tickets, etc.
    }

    function selectWinners() public onlySeller lotteryStarted {
        require(eligibleParticipants.length >= numberOfTickets, "Not enough eligible participants");

        uint256 winnersCount = 0;
        while (winnersCount < numberOfTickets) {
            uint256 randomIndex = _getRandomNumber(block.timestamp, eligibleParticipants.length);
            address selectedWinner = eligibleParticipants[randomIndex];

            if (!depositContract.isWinner(selectedWinner)) {
                depositContract.setWinner(selectedWinner);
                winnersCount++;
            }
        }
    }

    // Function to check and mark eligible participants
    function checkEligibleParticipants() internal {
        address[] memory participants = depositContract.getParticipants();
        for (uint256 i = 0; i < participants.length; i++) {
            uint256 depositedAmount = depositContract.getDepositedAmount(participants[i]);
            if (depositedAmount >= minimumDepositAmount) {
                // Mark this participant as eligible for the lottery
                eligibleParticipants.push(participants[i]);
            }
        }
    }

    function isParticipantEligible(address participant) public view returns (bool) {
        for (uint256 i = 0; i < eligibleParticipants.length; i++) {
            if (eligibleParticipants[i] == participant) {
                return true;
            }
        }
        return false;
    }

    function mintMyNFT(uint256 tokenId) public lotteryEnded isWinner hasNotMinted validTokenId(tokenId) {
        require(eligibleParticipants.length > 0, "No eligible participants");

        _mint(msg.sender, tokenId, 1, ""); // Mint 1 NFT to the winner
        hasMinted[msg.sender] = true; // Mark that the winner has minted their NFT
    }
}
