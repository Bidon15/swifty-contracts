// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/NFTLotteryTicket.sol";
import "../src/Deposit.sol";
import { VRFCoordinatorV2Mock } from "@chainlink/contracts/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract NFTLotteryTicketTest is Test {
    NFTLotteryTicket private nftLotteryTicket;
    VRFCoordinatorV2Mock public vrfMock;
    Deposit private deposit;
    
    uint256 private sellerPrivateKey = 0xa11ce;
    uint256 private multisigWalletPrivateKey = 0xb334d;
    address seller;

    function setUp() public {
        seller = vm.addr(sellerPrivateKey);
        
        vrfMock = new VRFCoordinatorV2Mock(0, 0);
        vm.startPrank(seller);
        uint64 subId = vrfMock.createSubscription();
        vrfMock.fundSubscription(subId, 1000000000000000000000);
        vm.stopPrank();

        deposit = new Deposit(seller, subId, address(vrfMock));
        nftLotteryTicket = new NFTLotteryTicket("ipfs://example_uri/");
        nftLotteryTicket.setDepositContractAddr(address(deposit));
        deposit.setNftContractAddr(address(nftLotteryTicket));
    }

    function test_NonWinnerCannotMint() public {
        address nonWinner = address(1);
        vm.prank(nonWinner);
        vm.expectRevert("Only deposit contract can mint");
        nftLotteryTicket.lotteryMint(nonWinner);
        vm.stopPrank();
    }

    function testWinnersCanMint() public {
        address joeWinner = address(1);
        address annaWinner = address(2);

        vm.startPrank(seller);
        deposit.startLottery();
        deposit.setWinner(joeWinner);
        deposit.setWinner(annaWinner);
        deposit.endLottery();
        vm.stopPrank();

        vm.prank(joeWinner);
        deposit.mintMyNFT();
        assertEq(nftLotteryTicket.balanceOf(joeWinner, 1), 1, "Joe must own NFT#1");

        vm.prank(annaWinner);
        deposit.mintMyNFT();
        assertEq(nftLotteryTicket.balanceOf(annaWinner, 2), 1, "Anna must own NFT#2");
    }    

    function testWinnersCannotMintTwice() public {
        address joeWinner = address(1);

        vm.startPrank(seller);
        deposit.startLottery();
        deposit.setWinner(joeWinner);
        deposit.endLottery();
        vm.stopPrank();

        vm.startPrank(joeWinner);
        deposit.mintMyNFT();
        assertEq(nftLotteryTicket.balanceOf(joeWinner, 1), 1, "Joe must own NFT#1");
        vm.expectRevert("NFT already minted");
        deposit.mintMyNFT();
        vm.stopPrank();
    }

    function testSoulbond() public {
        address joeWinner = address(1);
        address annaWinner = address(2);

        vm.startPrank(seller);
        deposit.startLottery();
        deposit.setWinner(joeWinner);
        deposit.setWinner(annaWinner);
        deposit.endLottery();
        vm.stopPrank();

        vm.prank(joeWinner);
        deposit.mintMyNFT();
        vm.expectRevert(NFTLotteryTicket.NonTransferable.selector);
        nftLotteryTicket.safeTransferFrom(joeWinner, annaWinner, 1, 1, "");
        vm.stopPrank();

        vm.prank(annaWinner);
        vm.expectRevert(NFTLotteryTicket.NonTransferable.selector);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 2;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        nftLotteryTicket.safeBatchTransferFrom(annaWinner, joeWinner, ids, amounts, "");
        vm.stopPrank();
    }
}
