// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Auctions.sol";
import "../src/BidTicket.sol";
import "./lib/Mock721.sol";
import "./lib/Mock1155.sol";

contract AuctionsTest is Test {
    Auctions public auctions;
    BidTicket public bidTicket;
    Mock721 public mock721;
    Mock1155 public mock1155;

    address public theBarn;
    address public theFarmer;
    address public user1;
    address public user2;

    uint256 public tokenCount = 10;
    uint256[] public tokenIds = [0, 1, 2];
    uint256[] public tokenIdsOther = [3, 4, 5];
    uint256[] public tokenIdAmounts = [10, 10, 10];
    uint256[] public amounts = [1, 1, 1];

    receive() external payable {}
    fallback() external payable {}

    function setUp() public {
        theBarn = vm.addr(1);
        theFarmer = vm.addr(123);

        bidTicket = new BidTicket(address(this));
        auctions = new Auctions(address(this), theBarn, theFarmer, address(bidTicket));
        mock721 = new Mock721();
        mock1155 = new Mock1155();

        user1 = vm.addr(2);
        user2 = vm.addr(3);

        bidTicket.setAuctionsContract(address(auctions));
        bidTicket.mint(user1, 1, 100);
        bidTicket.mint(user2, 1, 100);

        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);

        mock721.mint(theBarn, tokenCount);
        mock1155.mintBatch(theBarn, tokenIds, tokenIdAmounts, "");

        vm.startPrank(theBarn);
        mock721.setApprovalForAll(address(auctions), true);
        mock1155.setApprovalForAll(address(auctions), true);
        vm.stopPrank();
    }

    //
    // startAuctionERC721()
    //
    function test_startAuctionERC721_Success() public {
        vm.startPrank(user1);

        uint256 startBalance = user1.balance;
        assertEq(bidTicket.balanceOf(user1, 1), 100);

        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);
        assertEq(user1.balance, startBalance - 0.05 ether, "Balance should decrease by 0.05 ether");
        assertEq(auctions.nextAuctionId(), 2, "nextAuctionId should be incremented");
        assertEq(bidTicket.balanceOf(user1, 1), 99);

        (, address tokenAddress,,,, address highestBidder, uint256 highestBid,,) = auctions.auctions(1);

        assertEq(tokenAddress, address(mock721));
        assertEq(highestBidder, user1);
        assertEq(highestBid, 0.05 ether);
    }

    function testFuzz_startAuctionERC721_Success(uint256 bidAmount) public {
        vm.assume(bidAmount > 0.05 ether);
        vm.assume(user1.balance >= bidAmount);

        vm.startPrank(user1);

        uint256 startBalance = user1.balance;
        assertEq(bidTicket.balanceOf(user1, 1), 100);

        auctions.startAuctionERC721{value: bidAmount}(bidAmount, address(mock721), tokenIds);
        assertEq(user1.balance, startBalance - bidAmount, "Balance should decrease by bid amount");
        assertEq(auctions.nextAuctionId(), 2, "nextAuctionId should be incremented");
        assertEq(bidTicket.balanceOf(user1, 1), 99);

        (, address tokenAddress,,,, address highestBidder, uint256 highestBid,,) = auctions.auctions(1);

        assertEq(tokenAddress, address(mock721));
        assertEq(highestBidder, user1);
        assertEq(highestBid, bidAmount);
    }

    function test_startAuctionERC721_Success_NextAuctionIdIncrements() public {
        uint256 nextAuctionId = auctions.nextAuctionId();

        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);
        skip(60 * 60 * 24 * 7 + 1);
        auctions.claim(nextAuctionId);

        mock721.transferFrom(user1, theBarn, tokenIds[0]);
        mock721.transferFrom(user1, theBarn, tokenIds[1]);
        mock721.transferFrom(user1, theBarn, tokenIds[2]);

        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);
        assertEq(auctions.nextAuctionId(), nextAuctionId + 2, "nextAuctionId should be incremented");
    }

    function test_startAuctionERC721_RevertIf_MaxTokensPerTxReached() public {
        auctions.setMaxTokens(10);
        vm.startPrank(user1);
        uint256[] memory manyTokenIds = new uint256[](11);
        vm.expectRevert(bytes4(keccak256("MaxTokensPerTxReached()")));
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), manyTokenIds);
    }

    function test_startAuctionERC721_RevertIf_StartPriceTooLow() public {
        vm.startPrank(user1);
        vm.expectRevert(bytes4(keccak256("StartPriceTooLow()")));
        auctions.startAuctionERC721{value: 0.04 ether}(0.04 ether, address(mock721), tokenIds);
    }

    function test_startAuctionERC721_RevertIf_BurnExceedsBalance() public {
        bidTicket.burn(user1, 1, 100);

        vm.startPrank(user1);
        vm.expectRevert(bytes4(keccak256("BurnExceedsBalance()")));
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);
    }

    function test_startAuctionERC721_RevertIf_TokenAlreadyInAuction() public {
        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);
        vm.expectRevert(bytes4(keccak256("TokenAlreadyInAuction()")));
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);
    }

    function test_startAuctionERC721_RevertIf_InvalidLengthOfTokenIds() public {
        vm.startPrank(user1);
        vm.expectRevert(bytes4(keccak256("InvalidLengthOfTokenIds()")));
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), new uint256[](0));
    }

    function test_startAuctionERC721_RevertIf_TokenNotOwned() public {
        mock721.mint(user2, 10);

        uint256[] memory notOwnedTokenIds = new uint256[](1);
        notOwnedTokenIds[0] = tokenCount + 1;

        vm.startPrank(user1);
        vm.expectRevert(bytes4(keccak256("TokenNotOwned()")));
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), notOwnedTokenIds);
    }

    //
    // startAuctionERC1155
    //
    function test_startAuctionERC1155_Success() public {
        vm.startPrank(user1);

        uint256 startBalance = user1.balance;
        assertEq(bidTicket.balanceOf(user1, 1), 100);

        auctions.startAuctionERC1155{value: 0.05 ether}(0.05 ether, address(mock1155), tokenIds, amounts);
        assertEq(user1.balance, startBalance - 0.05 ether, "Balance should decrease by 0.05 ether");
        assertEq(auctions.nextAuctionId(), 2, "nextAuctionId should be incremented");
        assertEq(bidTicket.balanceOf(user1, 1), 99);

        (, address tokenAddress,,,, address highestBidder, uint256 highestBid,,) = auctions.auctions(1);

        assertEq(tokenAddress, address(mock1155));
        assertEq(highestBidder, user1);
        assertEq(highestBid, 0.05 ether);
    }

    function test_startAuctionERC1155_RevertIf_StartPriceTooLow() public {
        vm.startPrank(user1);
        vm.expectRevert(bytes4(keccak256("StartPriceTooLow()")));
        auctions.startAuctionERC1155{value: 0.04 ether}(0.04 ether, address(mock721), tokenIds, amounts);
    }

    function test_startAuctionERC1155_RevertIf_InvalidLengthOfTokenIds() public {
        vm.startPrank(user1);
        vm.expectRevert(bytes4(keccak256("InvalidLengthOfTokenIds()")));
        auctions.startAuctionERC1155{value: 0.05 ether}(0.05 ether, address(mock1155), new uint256[](0), amounts);
    }

    function test_startAuctionERC1155_RevertIf_InvalidLengthOfAmounts() public {
        vm.startPrank(user1);
        vm.expectRevert(bytes4(keccak256("InvalidLengthOfAmounts()")));
        auctions.startAuctionERC1155{value: 0.05 ether}(0.05 ether, address(mock1155), tokenIds, new uint256[](0));
    }

    function test_startAuctionERC1155_RevertIf_MaxTokensPerTxReached() public {
        auctions.setMaxTokens(10);
        uint256[] memory manyTokenIds = new uint256[](11);
        uint256[] memory manyAmounts = new uint256[](11);

        for (uint256 i; i < 11; i++) {
            manyTokenIds[i] = i;
            manyAmounts[i] = 1;
        }

        mock1155.mintBatch(theBarn, manyTokenIds, manyAmounts, "");

        vm.prank(user1);
        vm.expectRevert(bytes4(keccak256("MaxTokensPerTxReached()")));
        auctions.startAuctionERC1155{value: 0.05 ether}(0.05 ether, address(mock1155), manyTokenIds, manyAmounts);
    }

    //
    // bid()
    //
    function test_bid_Success() public {
        vm.startPrank(user1);
        assertEq(bidTicket.balanceOf(user1, 1), 100);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);
        assertEq(bidTicket.balanceOf(user1, 1), 99);
        vm.stopPrank();

        vm.startPrank(user2);
        auctions.bid{value: 0.06 ether}(1, 0.06 ether);
        assertEq(bidTicket.balanceOf(user1, 1), 99);
        assertEq(bidTicket.balanceOf(user2, 1), 99);

        (,,,,, address highestBidder, uint256 highestBid,,) = auctions.auctions(1);

        assertEq(highestBidder, user2, "Highest bidder should be this contract");
        assertEq(highestBid, 0.06 ether, "Highest bid should be 0.06 ether");
    }

    function test_bid_Success_LastMinuteBidding() public {
        vm.startPrank(user1);

        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);
        (,, uint256 endTimeA,,,,,,) = auctions.auctions(1);

        skip(60 * 60 * 24 * 3 - 1); // 1 second before auction ends

        vm.startPrank(user2);
        auctions.bid{value: 0.06 ether}(1, 0.06 ether);

        (,, uint256 endTimeB,,,,,,) = auctions.auctions(1);

        assertLt(endTimeA, endTimeB, "New endtime should be greater than old endtime");
    }

    function test_bid_RevertIf_BelowMinimumIncrement() public {
        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert(bytes4(keccak256("BidTooLow()")));
        auctions.bid{value: 0.055 ether}(1, 0.055 ether);
        vm.stopPrank();
    }

    function test_bid_RevertIf_BidEqualsHighestBid() public {
        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);
        vm.stopPrank();

        uint256 auctionId = auctions.nextAuctionId() - 1;

        vm.startPrank(user2);
        auctions.bid{value: 0.06 ether}(auctionId, 0.06 ether);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(bytes4(keccak256("BidTooLow()")));
        auctions.bid{value: 0.06 ether}(auctionId, 0.06 ether);
        vm.stopPrank();
    }

    function test_bid_RevertIf_AfterAuctionEnded() public {
        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);
        vm.stopPrank();

        skip(60 * 60 * 24 * 7 + 1);

        vm.startPrank(user2);
        vm.expectRevert(bytes4(keccak256("AuctionEnded()")));
        auctions.bid{value: 0.06 ether}(1, 0.06 ether);
        vm.stopPrank();
    }

    function testFuzz_bid_Success(uint256 bidA, uint256 bidB) public {
        uint256 _bidA = bound(bidA, 0.05 ether, 1000 ether);
        uint256 _bidB = bound(bidB, _bidA + auctions.minBidIncrement(), 10000 ether);

        vm.deal(user1, _bidA);
        vm.deal(user2, _bidB);
        vm.assume(_bidB > _bidA);

        vm.prank(user1);
        auctions.startAuctionERC721{value: _bidA}(_bidA, address(mock721), tokenIds);

        vm.prank(user2);
        auctions.bid{value: _bidB}(1, _bidB);
        assertEq(bidTicket.balanceOf(user1, 1), 99);
        assertEq(bidTicket.balanceOf(user2, 1), 99);

        (,,,,, address highestBidder, uint256 highestBid,,) = auctions.auctions(1);

        assertEq(highestBidder, user2, "Highest bidder should be this contract");
        assertEq(highestBid, _bidB, "Highest bid should be 0.06 ether");
    }

    //
    // claim()
    //
    function test_claim_Success_ERC721() public {
        vm.startPrank(user1);

        uint256 auctionId = auctions.nextAuctionId();
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);
        assertEq(user1.balance, 0.95 ether, "user1 should have 0.95 after starting the auction");

        vm.startPrank(user2);
        auctions.bid{value: 0.06 ether}(auctionId, 0.06 ether);

        (,,,,, address highestBidder, uint256 highestBid,,) = auctions.auctions(auctionId);

        assertEq(user2.balance, 0.94 ether, "user2 should have 0.95 ether in wallet");
        assertEq(highestBidder, user2, "Highest bidder should be user1");
        assertEq(highestBid, 0.06 ether, "Highest bid should be 0.06 ether");

        skip(60 * 60 * 24 * 7 + 1);
        auctions.claim(auctionId);

        assertEq(mock721.ownerOf(tokenIds[0]), user2, "Should own token 0");
        assertEq(mock721.ownerOf(tokenIds[1]), user2, "Should own token 1");
        assertEq(mock721.ownerOf(tokenIds[2]), user2, "Should own token 2");

        assertEq(theFarmer.balance, 0.06 ether - 0.005 ether, "The farmer should have 0.055 ether in wallet");
    }

    function test_claim_Success_ERC1155() public {
        vm.startPrank(user1);

        assertEq(mock1155.balanceOf(theBarn, tokenIds[0]), 10, "Should own token 0");
        assertEq(mock1155.balanceOf(theBarn, tokenIds[1]), 10, "Should own token 1");
        assertEq(mock1155.balanceOf(theBarn, tokenIds[2]), 10, "Should own token 2");
        assertEq(mock1155.isApprovedForAll(theBarn, address(auctions)), true, "Should be approved for all");

        uint256 auctionId = auctions.nextAuctionId();
        auctions.startAuctionERC1155{value: 0.05 ether}(0.05 ether, address(mock1155), tokenIds, amounts);
        assertEq(user1.balance, 0.95 ether, "user1 should have 0.95 after starting the auction");

        vm.startPrank(user2);
        auctions.bid{value: 0.06 ether}(auctionId, 0.06 ether);

        (,,,,, address highestBidder, uint256 highestBid,,) = auctions.auctions(auctionId);

        assertEq(user2.balance, 0.94 ether, "user2 should have 0.95 ether in wallet");
        assertEq(highestBidder, user2, "Highest bidder should be user1");
        assertEq(highestBid, 0.06 ether, "Highest bid should be 0.06 ether");

        skip(60 * 60 * 24 * 7 + 1);
        auctions.claim(auctionId);

        assertEq(mock1155.balanceOf(user2, tokenIds[0]), 1, "Should own token 0");
        assertEq(mock1155.balanceOf(user2, tokenIds[1]), 1, "Should own token 1");
        assertEq(mock1155.balanceOf(user2, tokenIds[2]), 1, "Should own token 2");

        assertEq(theFarmer.balance, 0.06 ether - 0.005 ether, "The farmer should have 0.055 ether in wallet");
    }

    function test_claim_Success_MultipleBids() public {
        auctions.setOutbidRewardPercent(0);
        
        uint256 auctionId = auctions.nextAuctionId();
        uint256 startingBid = 0.05 ether;

        vm.startPrank(user1);
        auctions.startAuctionERC721{value: startingBid}(startingBid, address(mock721), tokenIds);
        vm.stopPrank();

        address[] memory bidders = new address[](5);
        uint256[] memory bidAmounts = new uint256[](5);

        for (uint256 i = 0; i < 5; i++) {
            bidders[i] = address(uint160(i + 1000));
            bidTicket.mint(bidders[i], 1, 100);
            bidAmounts[i] = startingBid + (i + 1) * 0.01 ether;
            vm.deal(bidders[i], bidAmounts[i]);
            vm.prank(bidders[i]);
            auctions.bid{value: bidAmounts[i]}(auctionId, bidAmounts[i]);
        }

        address highestBidder = bidders[4];

        skip(60 * 60 * 24 * 7 + 1);

        for (uint256 i = 0; i < 4; i++) {
            assertEq(auctions.balances(bidders[i]), bidAmounts[i], "Outbid bidder balance should be correct");
        }

        assertEq(auctions.balances(highestBidder), 0, "Highest bidder should have no balance in contract");

        vm.prank(highestBidder);
        auctions.claim(auctionId);

        (,,,, Status status,,,,) = auctions.auctions(auctionId);
        assertTrue(status == Status.Claimed, "Auction should be marked as claimed");
        assertEq(mock721.ownerOf(tokenIds[0]), highestBidder, "Highest bidder should own token 0");
        assertEq(mock721.ownerOf(tokenIds[1]), highestBidder, "Highest bidder should own token 1");
        assertEq(mock721.ownerOf(tokenIds[2]), highestBidder, "Highest bidder should own token 2");

        for (uint256 i = 0; i < 4; i++) {
            assertEq(auctions.balances(bidders[i]), bidAmounts[i], "Outbid bidder balance should remain unchanged");
        }

        assertEq(auctions.balances(highestBidder), 0, "Highest bidder should still have no balance in contract");
        assertEq(theFarmer.balance, startingBid + (5 * 0.01 ether), "The farmer should have 0.055 ether in wallet");
    }

    function test_claim_Success_100Bids() public {
        auctions.setMinBidIncrement(0.001 ether);
        auctions.setOutbidRewardPercent(0);

        uint256 auctionId = auctions.nextAuctionId();
        uint256 startingBid = 0.05 ether;

        vm.startPrank(user1);
        auctions.startAuctionERC721{value: startingBid}(startingBid, address(mock721), tokenIds);
        vm.stopPrank();

        uint256 numBids = 100;
        address[] memory bidders = new address[](numBids);
        uint256[] memory bidAmounts = new uint256[](numBids);
        
        for (uint256 i = 0; i < numBids; i++) {
            bidders[i] = address(uint160(i + 1000));
            bidTicket.mint(bidders[i], 1, 100);
            bidAmounts[i] = startingBid + (i + 1) * 0.001 ether;
            vm.deal(bidders[i], bidAmounts[i]);
            vm.prank(bidders[i]);
            auctions.bid{value: bidAmounts[i]}(auctionId, bidAmounts[i]);
        }

        address highestBidder = bidders[numBids - 1];

        skip(60 * 60 * 24 * 7 + 1);

        for (uint256 i = 0; i < numBids - 1; i += 50) {
            assertEq(auctions.balances(bidders[i]), bidAmounts[i], "Outbid bidder balance should be correct");
        }

        assertEq(auctions.balances(highestBidder), 0, "Highest bidder should have no balance in contract");

        uint256 gasStart = gasleft();
        vm.prank(highestBidder);
        auctions.claim(auctionId);
        uint256 gasUsed = gasStart - gasleft();

        console.log("Gas used for claim:", gasUsed);

        (,,,, Status status,,,,) = auctions.auctions(auctionId);
        assertTrue(status == Status.Claimed, "Auction should be marked as claimed");
        assertEq(mock721.ownerOf(tokenIds[0]), highestBidder, "Highest bidder should own token 0");
        assertEq(mock721.ownerOf(tokenIds[1]), highestBidder, "Highest bidder should own token 1");
        assertEq(mock721.ownerOf(tokenIds[2]), highestBidder, "Highest bidder should own token 2");

        for (uint256 i = 0; i < numBids - 1; i += 50) {
            assertEq(auctions.balances(bidders[i]), bidAmounts[i], "Outbid bidder balance should remain unchanged");
        }

        assertEq(auctions.balances(highestBidder), 0, "Highest bidder should still have no balance in contract");

        for (uint256 i = 0; i < numBids - 1; i++) {
            uint256 balanceBefore = bidders[i].balance;
            vm.prank(bidders[i]);
            auctions.withdraw();
            assertEq(bidders[i].balance, balanceBefore + bidAmounts[i], "Bidder should be able to withdraw their balance");
            assertEq(auctions.balances(bidders[i]), 0, "Bidder balance in contract should be 0 after withdrawal");
        }

        assertEq(theFarmer.balance, startingBid + (100 * 0.001 ether), "The farmer should have 0.055 ether in wallet");
    }

    function test_claim_RevertIf_BeforeAuctionEnded() public {
        vm.startPrank(user1);

        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);
        vm.expectRevert(bytes4(keccak256("AuctionNotEnded()")));
        auctions.claim(1);
    }

    function test_claim_RevertIf_NotHighestBidder() public {
        vm.startPrank(user1);

        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);

        skip(60 * 60 * 24 * 7 + 1);

        vm.startPrank(user2);
        vm.expectRevert(bytes4(keccak256("NotHighestBidder()")));
        auctions.claim(1);
    }

    function test_claim_RevertIf_AbandonedAuction() public {
        uint256 auctionId = auctions.nextAuctionId();

        vm.prank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);

        skip(60 * 60 * 24 * 14 + 1);

        auctions.abandon(auctionId);

        vm.prank(user1);
        vm.expectRevert(bytes4(keccak256("InvalidStatus()")));
        auctions.claim(auctionId);
    }

    function test_claim_RevertIf_AuctionRefunded() public {
        vm.prank(theBarn);
        mock721.setApprovalForAll(address(auctions), false);
        uint256 auctionId = auctions.nextAuctionId();

        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);

        skip(60 * 60 * 24 * 7 + 1);

        auctions.refund(auctionId);
        vm.expectRevert(bytes4(keccak256("InvalidStatus()")));
        auctions.claim(auctionId);
    }

    function test_claim_RevertIf_AuctionClaimed() public {
        uint256 auctionId = auctions.nextAuctionId();

        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);

        skip(60 * 60 * 24 * 7 + 1);

        auctions.claim(auctionId);
        vm.expectRevert(bytes4(keccak256("InvalidStatus()")));
        auctions.claim(auctionId);
    }

    //
    // refund
    //
    function test_refund_Success_ERC721() public {
        uint256 auctionId = auctions.nextAuctionId();
        auctions.setMaxTokens(50);
        vm.prank(theBarn);
        mock721.setApprovalForAll(address(auctions), false);

        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);

        assertEq(user1.balance, 1 ether - 0.05 ether, "user1 should have 0.05 less");
        assertTrue(auctions.auctionTokensERC721(address(mock721), tokenIds[0]), "Token 0 should not be in auction");
        assertTrue(auctions.auctionTokensERC721(address(mock721), tokenIds[1]), "Token 1 should not be in auction");
        assertTrue(auctions.auctionTokensERC721(address(mock721), tokenIds[2]), "Token 2 should not be in auction");

        skip(60 * 60 * 24 * 7 + 1);

        auctions.refund(auctionId);
        assertEq(auctions.balances(user1), 0.05 ether, "user1 should have 0.05 ether again");

        (,,,, Status status,,,,) = auctions.auctions(auctionId);

        assertTrue(status == Status.Refunded, "Auction should be marked as refunded");
        assertFalse(auctions.auctionTokensERC721(address(mock721), tokenIds[0]), "Token 0 should not be in auction");
        assertFalse(auctions.auctionTokensERC721(address(mock721), tokenIds[1]), "Token 1 should not be in auction");
        assertFalse(auctions.auctionTokensERC721(address(mock721), tokenIds[2]), "Token 2 should not be in auction");
    }

    function test_refund_Success_ERC1155() public {
        uint256 auctionId = auctions.nextAuctionId();
        auctions.setMaxTokens(50);
        vm.prank(theBarn);
        mock1155.setApprovalForAll(address(auctions), false);

        vm.startPrank(user1);
        auctions.startAuctionERC1155{value: 0.05 ether}(0.05 ether, address(mock1155), tokenIds, tokenIdAmounts);

        assertEq(user1.balance, 1 ether - 0.05 ether, "user1 should have 0.05 less");
        assertEq(auctions.auctionTokensERC1155(address(mock1155), tokenIds[0]), 10, "Token 0 should have 10 in auction");
        assertEq(auctions.auctionTokensERC1155(address(mock1155), tokenIds[1]), 10, "Token 1 should have 10 in auction");
        assertEq(auctions.auctionTokensERC1155(address(mock1155), tokenIds[2]), 10, "Token 2 should have 10 in auction");

        skip(60 * 60 * 24 * 7 + 1);

        auctions.refund(auctionId);
        assertEq(auctions.balances(user1), 0.05 ether, "user1 should have 0.05 ether again");

        (,,,, Status status,,,,) = auctions.auctions(auctionId);

        assertTrue(status == Status.Refunded, "Auction should be marked as refunded");
        assertEq(auctions.auctionTokensERC1155(address(mock1155), tokenIds[0]), 0, "Token 0 should have 0 in auction");
        assertEq(auctions.auctionTokensERC1155(address(mock1155), tokenIds[1]), 0, "Token 1 should have 0 in auction");
        assertEq(auctions.auctionTokensERC1155(address(mock1155), tokenIds[2]), 0, "Token 2 should have 0 in auction");
    }

    function test_refund_RevertIf_AuctionActive() public {
        vm.prank(theBarn);
        mock721.setApprovalForAll(address(auctions), false);

        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);
        vm.expectRevert(bytes4(keccak256("AuctionActive()")));
        auctions.refund(1);
    }

    function test_refund_RevertIf_SettlementPeriodEnded() public {
        vm.prank(theBarn);
        mock721.setApprovalForAll(address(auctions), false);

        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);

        skip(60 * 60 * 24 * 14 + 1);

        vm.expectRevert(bytes4(keccak256("SettlementPeriodEnded()")));
        auctions.refund(1);
    }

    function test_refund_RevertIf_NotHighestBidder() public {
        vm.prank(theBarn);
        mock721.setApprovalForAll(address(auctions), false);

        vm.prank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);

        skip(60 * 60 * 24 * 7 + 1);

        vm.prank(user2);
        vm.expectRevert(bytes4(keccak256("NotHighestBidder()")));
        auctions.refund(1);
    }

    function test_refund_RevertIf_AuctionRefunded() public {
        uint256 auctionId = auctions.nextAuctionId();
        vm.prank(theBarn);
        mock721.setApprovalForAll(address(auctions), false);

        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);

        skip(60 * 60 * 24 * 7 + 1);

        auctions.refund(auctionId);
        vm.expectRevert(bytes4(keccak256("InvalidStatus()")));
        auctions.refund(auctionId);
    }

    function test_refund_RevertIf_AuctionClaimed() public {
        uint256 auctionId = auctions.nextAuctionId();

        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);

        skip(60 * 60 * 24 * 7 + 1);

        auctions.claim(auctionId);
        vm.expectRevert(bytes4(keccak256("InvalidStatus()")));
        auctions.refund(auctionId);
    }

    //
    // abandon
    //
    function test_abandon_Success_ERC721() public {
        uint256 auctionId = auctions.nextAuctionId();
        uint256 startingBid = 0.05 ether;

        vm.prank(user1);
        auctions.startAuctionERC721{value: startingBid}(startingBid, address(mock721), tokenIds);

        assertEq(user1.balance, 0.95 ether, "user1 should have 0.95 after starting the auction");
        assertTrue(auctions.auctionTokensERC721(address(mock721), tokenIds[0]), "Token 0 should not be in auction");
        assertTrue(auctions.auctionTokensERC721(address(mock721), tokenIds[1]), "Token 1 should not be in auction");
        assertTrue(auctions.auctionTokensERC721(address(mock721), tokenIds[2]), "Token 2 should not be in auction");

        skip(60 * 60 * 24 * 14 + 1);

        vm.startPrank(address(this));
        auctions.abandon(auctionId);

        assertEq(
            auctions.balances(user1),
            startingBid - startingBid * auctions.abandonmentFeePercent() / 100,
            "user1 should have 1 ether - fee"
        );

        assertEq(theFarmer.balance, startingBid * auctions.abandonmentFeePercent() / 100, "The farmer should have abandonment fee in wallet");

        (,,,, Status status,,,,) = auctions.auctions(auctionId);

        assertTrue(status == Status.Abandoned, "Auction should be marked as abandoned");
        assertFalse(auctions.auctionTokensERC721(address(mock721), tokenIds[0]), "Token 0 should not be in auction");
        assertFalse(auctions.auctionTokensERC721(address(mock721), tokenIds[1]), "Token 1 should not be in auction");
        assertFalse(auctions.auctionTokensERC721(address(mock721), tokenIds[2]), "Token 2 should not be in auction");
    }

    function test_abandon_Success_ERC1155() public {
        uint256 auctionId = auctions.nextAuctionId();
        uint256 startingBid = 0.05 ether;
        auctions.setMaxTokens(50);

        vm.prank(user1);
        auctions.startAuctionERC1155{value: startingBid}(startingBid, address(mock1155), tokenIds, tokenIdAmounts);

        assertEq(user1.balance, 0.95 ether, "user1 should have 0.95 after starting the auction");
        assertEq(auctions.auctionTokensERC1155(address(mock1155), tokenIds[0]), 10, "Token 0 should have 10 in auction");
        assertEq(auctions.auctionTokensERC1155(address(mock1155), tokenIds[1]), 10, "Token 1 should have 10 in auction");
        assertEq(auctions.auctionTokensERC1155(address(mock1155), tokenIds[2]), 10, "Token 2 should have 10 in auction");

        skip(60 * 60 * 24 * 14 + 1);

        vm.startPrank(address(this));
        auctions.abandon(auctionId);

        assertEq(
            auctions.balances(user1),
            startingBid - startingBid * auctions.abandonmentFeePercent() / 100,
            "user1 should have 1 ether - fee"
        );

        assertEq(theFarmer.balance, startingBid * auctions.abandonmentFeePercent() / 100, "The farmer should have abandonment fee in wallet");

        (,,,, Status status,,,,) = auctions.auctions(auctionId);

        assertTrue(status == Status.Abandoned, "Auction should be marked as abandoned");
        assertEq(auctions.auctionTokensERC1155(address(mock1155), tokenIds[0]), 0, "Token 0 should have 0 in auction");
        assertEq(auctions.auctionTokensERC1155(address(mock1155), tokenIds[1]), 0, "Token 1 should have 0 in auction");
        assertEq(auctions.auctionTokensERC1155(address(mock1155), tokenIds[2]), 0, "Token 2 should have 0 in auction");
    }

    function test_abandon_RevertIf_AuctionActive() public {
        vm.prank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);

        vm.expectRevert(bytes4(keccak256("SettlementPeriodNotExpired()")));
        auctions.abandon(1);
    }

    function test_abandon_RevertIf_SettlementPeriodActive() public {
        vm.prank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);

        skip(60 * 60 * 24 * 7 + 1);

        vm.expectRevert(bytes4(keccak256("SettlementPeriodNotExpired()")));
        auctions.abandon(1);
    }

    function test_abandon_RevertIf_AuctionAbandoned() public {
        vm.prank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);

        skip(60 * 60 * 24 * 14 + 1);

        auctions.abandon(1);
        vm.expectRevert(bytes4(keccak256("InvalidStatus()")));
        auctions.abandon(1);
    }

    function test_abandon_RevertIf_AuctionRefunded() public {
        vm.prank(theBarn);
        mock721.setApprovalForAll(address(auctions), false);

        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);
        skip(60 * 60 * 24 * 7 + 1);
        auctions.refund(1);
        vm.stopPrank();

        skip(60 * 60 * 24 * 7);

        vm.expectRevert(bytes4(keccak256("InvalidStatus()")));
        auctions.abandon(1);
    }

    function test_abandon_RevertIf_AuctionClaimed() public {
        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);
        skip(60 * 60 * 24 * 14 + 1);
        auctions.claim(1);
        vm.stopPrank();

        vm.expectRevert(bytes4(keccak256("InvalidStatus()")));
        auctions.abandon(1);
    }

    //
    // withdraw
    //
    function test_withdraw_Success() public {
        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);
        vm.stopPrank();

        vm.startPrank(user2);
        auctions.bid{value: 0.06 ether}(1, 0.06 ether);
        vm.stopPrank();

        assertEq(auctions.balances(user1), 0.05 ether, "User1 should have 0.05 ether balance in contract");

        uint256 initialBalance = user1.balance;

        vm.prank(user1);
        auctions.withdraw();

        assertEq(user1.balance, initialBalance + 0.05 ether, "User1 balance should increase by 0.05 ether");
        assertEq(auctions.balances(user1), 0, "User1 balance in contract should be 0 after withdrawal");
    }

    //
    // processPayment
    //
    function test_processPayment_Success() public {
        vm.startPrank(user1);
        uint256 initialBalance = address(auctions).balance;
        uint256 bidAmount = 0.05 ether;

        auctions.startAuctionERC721{value: bidAmount}(bidAmount, address(mock721), tokenIds);

        assertEq(address(auctions).balance, initialBalance + bidAmount, "Contract balance should increase by bid amount");
        assertEq(auctions.balances(user1), 0, "User balance in contract should be 0");
    }

    //
    // getters/setters
    //
    function test_getAuctionTokens_Success_ERC721() public {
        auctions.setMaxTokens(50);

        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);

        (, address tokenAddress,,,,,,,) = auctions.auctions(1);
        assertEq(tokenAddress, address(mock721));

        (uint256[] memory _tokenIds, uint256[] memory _amounts) = auctions.getAuctionTokens(1);

        assertEq(_tokenIds[0], tokenIds[0]);
        assertEq(_tokenIds[1], tokenIds[1]);
        assertEq(_tokenIds[2], tokenIds[2]);
        assertEq(_amounts[0], amounts[0]);
        assertEq(_amounts[1], amounts[1]);
        assertEq(_amounts[2], amounts[2]);
    }

    function test_getAuctionTokens_Success_ERC1155() public {
        auctions.setMaxTokens(50);
        vm.startPrank(user1);
        auctions.startAuctionERC1155{value: 0.05 ether}(0.05 ether, address(mock1155), tokenIds, tokenIdAmounts);

        (, address tokenAddress,,,,,,,) = auctions.auctions(1);
        assertEq(tokenAddress, address(mock1155));

        (uint256[] memory _tokenIds, uint256[] memory _amounts) = auctions.getAuctionTokens(1);

        assertEq(_tokenIds[0], tokenIds[0]);
        assertEq(_tokenIds[1], tokenIds[1]);
        assertEq(_tokenIds[2], tokenIds[2]);
        assertEq(_amounts[0], tokenIdAmounts[0]);
        assertEq(_amounts[1], tokenIdAmounts[1]);
        assertEq(_amounts[2], tokenIdAmounts[2]);
    }

    function test_getClaimedAuctions_Success() public {
        uint256 numAuctions = 5;

        vm.startPrank(user1);

        for (uint256 i = 0; i < numAuctions; i++) {    
            uint256[] memory _tokenIds = new uint256[](1);
            _tokenIds[0] = i;
            auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), _tokenIds);

            uint256 auctionId = auctions.nextAuctionId() - 1;

            skip(60 * 60 * 24 * 7 + 1);

            auctions.claim(auctionId);
        }

        // Test with different limits
        uint256[] memory claimedAuctions;

        // Test with limit less than total claimed auctions
        claimedAuctions = auctions.getClaimedAuctions(3);
        assertEq(claimedAuctions.length, 3, "Should return 3 claimed auctions");

        for (uint256 i = 0; i < 3; i++) {
            assertEq(claimedAuctions[i], 5 - i, "Auction IDs should be in descending order");
        }

        // Test with limit equal to total claimed auctions
        claimedAuctions = auctions.getClaimedAuctions(5);
        assertEq(claimedAuctions.length, 5, "Should return all 5 claimed auctions");

        for (uint256 i = 0; i < 5; i++) {
            assertEq(claimedAuctions[i], 5 - i, "Auction IDs should be in descending order");
        }

        // Test with limit greater than total claimed auctions
        claimedAuctions = auctions.getClaimedAuctions(10);
        assertEq(claimedAuctions.length, 5, "Should return only 5 claimed auctions");

        for (uint256 i = 0; i < 5; i++) {
            assertEq(claimedAuctions[i], 5 - i, "Auction IDs should be in descending order");
        }
    }

    function test_setMinStartingBid_Success() public {
        auctions.setMinStartingBid(0.01 ether);

        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.01 ether}(0.01 ether, address(mock721), tokenIds);
    }

    function test_setMintBidIncrement_Success() public {
        auctions.setMinBidIncrement(0.02 ether);

        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);
        vm.stopPrank();

        vm.startPrank(user2);
        auctions.bid{value: 0.07 ether}(1, 0.07 ether);
        vm.stopPrank();

        vm.startPrank(user1);
        auctions.bid{value: 0.04 ether}(1, 0.09 ether);
        vm.stopPrank();
    }

    function test_setMinBidIncrement_RevertIf_BidTooLow() public {
        auctions.setMinBidIncrement(0.02 ether);

        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.05 ether}(0.05 ether, address(mock721), tokenIds);
        vm.stopPrank();

        vm.startPrank(user2);
        auctions.bid{value: 0.07 ether}(1, 0.07 ether);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(bytes4(keccak256("BidTooLow()")));
        auctions.bid{value: 0.08 ether}(1, 0.08 ether);
        vm.stopPrank();
    }

    function test_setBarnAddress_Success() public {
        auctions.setBarnAddress(vm.addr(420));
    }

    function test_setBarnAddress_RevertIf_NotOwner() public {
        vm.prank(vm.addr(69));
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        auctions.setBarnAddress(vm.addr(420));
    }

    function test_setBidTicketAddress_Success() public {
        auctions.setBidTicketAddress(vm.addr(420));
    }

    function test_setBidTicketAddress_RevertIf_NotOwner() public {
        vm.prank(vm.addr(69));
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        auctions.setBidTicketAddress(vm.addr(420));
    }

    function test_setBidTicketTokenId_Success() public {
        auctions.setBidTicketTokenId(255);
    }

    function test_setBidTicketTokenId_RevertIf_NotOwner() public {
        vm.prank(vm.addr(69));
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        auctions.setBidTicketTokenId(255);
    }

    function test_setMaxTokens_Success() public {
        auctions.setMaxTokens(255);
    }

    function test_setMaxTokens_RevertIf_NotOwner() public {
        vm.prank(vm.addr(69));
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        auctions.setMaxTokens(255);
    }

    function test_setAuctionDuration_Success() public {
        auctions.setAuctionDuration(60 * 60 * 24 * 7);
    }

    function test_setAuctionDuration_RevertIf_NotOwner() public {
        vm.prank(vm.addr(69));
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        auctions.setAuctionDuration(60 * 60 * 24 * 7);
    }

    function test_setSettlementDuration_Success() public {
        auctions.setSettlementDuration(60 * 60 * 24 * 7);
    }

    function test_setSettlementDuration_RevertIf_NotOwner() public {
        vm.prank(vm.addr(69));
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        auctions.setSettlementDuration(60 * 60 * 24 * 7);
    }

    function test_outbidRewards_Success() public {
        auctions.setOutbidRewardPercent(10); // 10% outbid reward

        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.1 ether}(0.1 ether, address(mock721), tokenIds);
        vm.stopPrank();

        assertEq(auctions.balances(user1), 0, "User1 should have no balance yet");

        vm.startPrank(user2);
        auctions.bid{value: 0.2 ether}(1, 0.2 ether);
        vm.stopPrank();

        assertEq(auctions.balances(user1), 0.1 ether, "User1 should have refund");

        vm.startPrank(user1);
        auctions.bid{value: 0.2 ether}(1, 0.3 ether);
        vm.stopPrank();

        assertEq(auctions.balances(user2), 0.2 ether, "User2 should have refund");

        vm.startPrank(user2);
        auctions.bid{value: 0.2 ether}(1, 0.4 ether);
        vm.stopPrank();

        assertEq(auctions.balances(user1), 0.3 ether, "User1 should have refund");

        skip(60 * 60 * 24 * 7 + 1);

        vm.prank(user2);
        auctions.claim(1);

        assertEq(auctions.balances(user1), 0.3 ether + 0.02 ether, "User1's balance should only include reward");
        assertEq(auctions.balances(user2), 0 ether + 0.01 ether, "User2's balance should include reward + refunded bid");
    }

    function test_outbidRewards_MultipleBidders() public {
        auctions.setOutbidRewardPercent(5); // 5% outbid reward

        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.1 ether}(0.1 ether, address(mock721), tokenIds);
        vm.stopPrank();

        address user3 = vm.addr(4);
        address user4 = vm.addr(5);
        vm.deal(user3, 1 ether);
        vm.deal(user4, 1 ether);
        bidTicket.mint(user3, 1, 100);
        bidTicket.mint(user4, 1, 100);

        vm.prank(user2);
        auctions.bid{value: 0.2 ether}(1, 0.2 ether);

        vm.prank(user3);
        auctions.bid{value: 0.3 ether}(1, 0.3 ether);

        vm.prank(user4);
        auctions.bid{value: 0.4 ether}(1, 0.4 ether);

        vm.prank(user1);
        auctions.bid{value: 0.4 ether}(1, 0.5 ether);

        vm.prank(user2);
        auctions.bid{value: 0.4 ether}(1, 0.6 ether);

        skip(60 * 60 * 24 * 3 + 1);
        
        vm.prank(user2);
        auctions.claim(1);
    }

    function test_outbidRewards_ZeroPercent() public {
        auctions.setOutbidRewardPercent(0); // 0% outbid reward

        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.1 ether}(0.1 ether, address(mock721), tokenIds);
        vm.stopPrank();

        vm.startPrank(user2);
        auctions.bid{value: 0.2 ether}(1, 0.2 ether);
        vm.stopPrank();

        assertEq(auctions.balances(user1) - 0.1 ether, 0, "User1 should not receive any outbid reward");

        vm.startPrank(user1);
        auctions.bid{value: 0.2 ether}(1, 0.3 ether);
        vm.stopPrank();

        assertEq(auctions.balances(user2) - 0.2 ether, 0, "User2 should not receive any outbid reward");
    }

    function test_outbidRewards_MaxPercent() public {
        auctions.setOutbidRewardPercent(100); // 100% outbid reward (extreme case)

        vm.startPrank(user1);
        auctions.startAuctionERC721{value: 0.1 ether}(0.1 ether, address(mock721), tokenIds);
        vm.stopPrank();

        vm.startPrank(user2);
        auctions.bid{value: 0.2 ether}(1, 0.2 ether);
        vm.stopPrank();

        assertEq(auctions.balances(user1), 0.1 ether, "User1 should receive 100% outbid reward");

        vm.startPrank(user1);
        auctions.bid{value: 0.2 ether}(1, 0.3 ether);
        vm.stopPrank();

        assertEq(auctions.balances(user2), 0.2 ether, "User2 should receive 100% outbid reward");
    }

    function testFuzz_outbidRewards(uint8 rewardPercent, uint256 initialBid, uint256 secondBidDelta) public {
        vm.assume(rewardPercent <= 100);
        vm.assume(initialBid >= 0.05 ether && initialBid < 100 ether);
        vm.assume(secondBidDelta > 0 && secondBidDelta < 1000 ether);

        uint256 secondBid = initialBid + 0.01 ether + secondBidDelta;

        auctions.setOutbidRewardPercent(rewardPercent);

        vm.deal(user1, initialBid);
        vm.deal(user2, secondBid);

        vm.prank(user1);
        auctions.startAuctionERC721{value: initialBid}(initialBid, address(mock721), tokenIds);

        uint256[] memory auctionIds = new uint256[](1);
        auctionIds[0] = 1;

        uint256 rewards = auctions.getPendingRewards(user1, auctionIds);
        assertEq(rewards, 0, "User1 should not have pending rewards");

        vm.prank(user2);
        auctions.bid{value: secondBid}(1, secondBid);

        skip(60 * 60 * 24 * 3 + 1);

        assertEq(auctions.balances(user1), initialBid, "User1 should have no rewards yet");

        uint256 expectedReward = initialBid * rewardPercent / 100;
        rewards = auctions.getPendingRewards(user1, auctionIds);
        assertEq(rewards, expectedReward, "User1 should have pending rewards");

        vm.prank(user2);
        auctions.claim(1);
        
        assertEq(auctions.balances(user1), initialBid + expectedReward, "User1 should receive the correct outbid reward");
    }
}
