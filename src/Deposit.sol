// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Deposit {
    enum LotteryState {
        NOT_STARTED,
        ACTIVE,
        ENDED
    }

    LotteryState public lotteryState;

    address public owner;
    address public lotteryContractAddress;
    address public multisigWalletAddress;
    address public seller;

    mapping(address => uint256) public deposits;
    mapping(address => bool) public winners;
    address[] public winnerAddresses;
    address[] private participants;

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _;
    }

    modifier onlyLotteryContract() {
        require(msg.sender == lotteryContractAddress, "Caller is not the lottery contract");
        _;
    }

    modifier whenLotteryNotActive() {
        require(lotteryState != LotteryState.ACTIVE, "Lottery is currently active");
        _;
    }

    constructor(address _seller) {
        owner = msg.sender;
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

    function getDepositedAmount(address participant) external view returns (uint256) {
        return deposits[participant];
    }

    function setLotteryAddress(address _lotteryContractAddress) public onlyOwner {
        lotteryContractAddress = _lotteryContractAddress;
    }

    function setMultisigWalletAddress(address _multisigWalletAddress) public onlyOwner {
        multisigWalletAddress = _multisigWalletAddress;
    }

    function changeLotteryState(LotteryState _newState) external onlyLotteryContract {
        lotteryState = _newState;
    }

    function isWinner(address _participant) public view returns (bool) {
        return winners[_participant];
    }

    function getWinners() public view returns (address[] memory) {
        return winnerAddresses;
    }

    function setWinner(address _winner) public onlyLotteryContract {
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

    function sellerWithdraw() public onlyLotteryContract {
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
}
