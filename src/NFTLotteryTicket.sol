// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { ERC1155 } from "../lib/openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import { Ownable } from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract NFTLotteryTicket is ERC1155, Ownable(msg.sender) {
    constructor(string memory uri) ERC1155(uri) {}

    uint256 public nextTokenId = 1;
    address public depositContractAddr;

    function setDepositContractAddr(address _depositContractAddr) public onlyOwner {
        depositContractAddr = _depositContractAddr;
    }

    function lotteryMint(address winner) public {
        require(msg.sender == depositContractAddr, "Only deposit contract can mint");

        _mint(winner, nextTokenId, 1, ""); // Mint 1 NFT to the winner
        nextTokenId++;
    }
}
