// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Market.sol";
import "../src/BidTicket.sol";
import "./lib/Mock721.sol";
import "./lib/Mock1155.sol";

contract MarketTest is Test {
    Market public market;
    BidTicket public bidTicket;
    Mock721 public mock721;
    Mock1155 public mock1155;

    address public theBarn;
    address public user1;
    address public user2;

    uint256 public tokenCount = 10;
    uint256[] public tokenIds = [0, 1, 2];
    uint256[] public tokenIdAmounts = [10, 10, 10];
    uint256[] public amounts = [1, 1, 1];

    receive() external payable {}
    fallback() external payable {}

    function setUp() public {
        theBarn = vm.addr(1);
        bidTicket = new BidTicket();
        market = new Market(theBarn, address(bidTicket));
        mock721 = new Mock721();
        mock1155 = new Mock1155();

        user1 = vm.addr(2);
        user2 = vm.addr(3);

        bidTicket.setMarketContract(address(market));
        bidTicket.mint(user1, 1, 100);
        bidTicket.mint(user2, 1, 100);

        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);

        mock721.mint(theBarn, tokenCount);
        mock1155.mintBatch(theBarn, tokenIds, tokenIdAmounts, "");

        vm.startPrank(theBarn);
        mock721.setApprovalForAll(address(market), true);
        mock1155.setApprovalForAll(address(market), true);
        vm.stopPrank();
    }

    //
    // startAuctionERC721()
    //
    function test_startAuctionERC721_Success() public {
        vm.startPrank(user1);

        uint256 startBalance = user1.balance;
        assertEq(bidTicket.balanceOf(user1, 1), 100);

        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        assertEq(user1.balance, startBalance - 0.05 ether, "Balance should decrease by 0.05 ether");
        assertEq(market.nextAuctionId(), 2, "nextAuctionId should be incremented");
        assertEq(bidTicket.balanceOf(user1, 1), 95);

        (, address tokenAddress,,,, address highestBidder, uint256 highestBid) = market.auctions(1);

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

        market.startAuctionERC721{value: bidAmount}(address(mock721), tokenIds);
        assertEq(user1.balance, startBalance - bidAmount, "Balance should decrease by bid amount");
        assertEq(market.nextAuctionId(), 2, "nextAuctionId should be incremented");
        assertEq(bidTicket.balanceOf(user1, 1), 95);

        (, address tokenAddress,,,, address highestBidder, uint256 highestBid) = market.auctions(1);

        assertEq(tokenAddress, address(mock721));
        assertEq(highestBidder, user1);
        assertEq(highestBid, bidAmount);
    }

    function test_startAuctionERC721_Success_NextAuctionIdIncrements() public {
        uint256 nextAuctionId = market.nextAuctionId();

        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        skip(60 * 60 * 24 * 7 + 1);
        market.claim(nextAuctionId);

        mock721.transferFrom(user1, theBarn, tokenIds[0]);
        mock721.transferFrom(user1, theBarn, tokenIds[1]);
        mock721.transferFrom(user1, theBarn, tokenIds[2]);

        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        assertEq(market.nextAuctionId(), nextAuctionId + 2, "nextAuctionId should be incremented");
    }

    function test_startAuctionERC721_RevertIf_MaxTokensPerTxReached() public {
        market.setMaxTokens(10);
        vm.startPrank(user1);
        uint256[] memory manyTokenIds = new uint256[](11);
        vm.expectRevert(bytes4(keccak256("MaxTokensPerTxReached()")));
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), manyTokenIds);
    }

    function test_startAuctionERC721_RevertIf_StartPriceTooLow() public {
        vm.startPrank(user1);
        vm.expectRevert(bytes4(keccak256("StartPriceTooLow()")));
        market.startAuctionERC721{value: 0.04 ether}(address(mock721), tokenIds);
    }

    function test_startAuctionERC721_RevertIf_BurnExceedsBalance() public {
        bidTicket.burn(user1, 1, 100);

        vm.startPrank(user1);
        vm.expectRevert(bytes4(keccak256("BurnExceedsBalance()")));
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
    }

    function test_startAuctionERC721_RevertIf_TokenAlreadyInAuction() public {
        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        vm.expectRevert(bytes4(keccak256("TokenAlreadyInAuction()")));
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
    }

    function test_startAuctionERC721_RevertIf_InvalidLengthOfTokenIds() public {
        vm.startPrank(user1);
        vm.expectRevert(bytes4(keccak256("InvalidLengthOfTokenIds()")));
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), new uint256[](0));
    }

    function test_startAuctionERC721_RevertIf_TokenNotOwned() public {
        mock721.mint(user2, 10);

        uint256[] memory notOwnedTokenIds = new uint256[](1);
        notOwnedTokenIds[0] = tokenCount + 1;

        vm.startPrank(user1);
        vm.expectRevert(bytes4(keccak256("TokenNotOwned()")));
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), notOwnedTokenIds);
    }

    //
    // startAuctionERC1155
    //
    function test_startAuctionERC1155_Success() public {
        vm.startPrank(user1);

        uint256 startBalance = user1.balance;
        assertEq(bidTicket.balanceOf(user1, 1), 100);

        market.startAuctionERC1155{value: 0.05 ether}(address(mock1155), tokenIds, amounts);
        assertEq(user1.balance, startBalance - 0.05 ether, "Balance should decrease by 0.05 ether");
        assertEq(market.nextAuctionId(), 2, "nextAuctionId should be incremented");
        assertEq(bidTicket.balanceOf(user1, 1), 95);

        (, address tokenAddress,,,, address highestBidder, uint256 highestBid) = market.auctions(1);

        assertEq(tokenAddress, address(mock1155));
        assertEq(highestBidder, user1);
        assertEq(highestBid, 0.05 ether);
    }

    function test_startAuctionERC1155_RevertIf_StartPriceTooLow() public {
        vm.startPrank(user1);
        vm.expectRevert(bytes4(keccak256("StartPriceTooLow()")));
        market.startAuctionERC1155{value: 0.04 ether}(address(mock721), tokenIds, amounts);
    }

    function test_startAuctionERC1155_RevertIf_InvalidLengthOfTokenIds() public {
        vm.startPrank(user1);
        vm.expectRevert(bytes4(keccak256("InvalidLengthOfTokenIds()")));
        market.startAuctionERC1155{value: 0.05 ether}(address(mock1155), new uint256[](0), amounts);
    }

    function test_startAuctionERC1155_RevertIf_InvalidLengthOfAmounts() public {
        vm.startPrank(user1);
        vm.expectRevert(bytes4(keccak256("InvalidLengthOfAmounts()")));
        market.startAuctionERC1155{value: 0.05 ether}(address(mock1155), tokenIds, new uint256[](0));
    }

    function test_startAuctionERC1155_RevertIf_MaxTokensPerTxReached() public {
        market.setMaxTokens(10);
        uint256[] memory manyTokenIds = new uint256[](11);
        uint256[] memory manyAmounts = new uint256[](11);

        for (uint256 i; i < 11; i++) {
            manyTokenIds[i] = i;
            manyAmounts[i] = 1;
        }

        mock1155.mintBatch(theBarn, manyTokenIds, manyAmounts, "");

        vm.prank(user1);
        vm.expectRevert(bytes4(keccak256("MaxTokensPerTxReached()")));
        market.startAuctionERC1155{value: 0.05 ether}(address(mock1155), manyTokenIds, manyAmounts);
    }

    //
    // bid()
    //
    function test_bid_Success() public {
        vm.startPrank(user1);
        assertEq(bidTicket.balanceOf(user1, 1), 100);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        assertEq(bidTicket.balanceOf(user1, 1), 95);
        vm.stopPrank();

        vm.startPrank(user2);
        market.bid{value: 0.06 ether}(1);
        assertEq(bidTicket.balanceOf(user1, 1), 95);
        assertEq(bidTicket.balanceOf(user2, 1), 99);

        (,,,,, address highestBidder, uint256 highestBid) = market.auctions(1);

        assertEq(highestBidder, user2, "Highest bidder should be this contract");
        assertEq(highestBid, 0.06 ether, "Highest bid should be 0.06 ether");
    }

    function test_bid_Success_SelfBidding() public {
        vm.startPrank(user1);

        assertEq(bidTicket.balanceOf(user1, 1), 100);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        assertEq(bidTicket.balanceOf(user1, 1), 95);
        market.bid{value: 0.06 ether}(1);
        assertEq(bidTicket.balanceOf(user1, 1), 94);

        (,,,,, address highestBidder, uint256 highestBid) = market.auctions(1);

        assertEq(highestBidder, user1, "Highest bidder should be this contract");
        assertEq(highestBid, 0.06 ether, "Highest bid should be 0.06 ether");
    }

    function test_bid_Success_LastMinuteBidding() public {
        vm.startPrank(user1);

        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        (,, uint256 endTimeA,,,,) = market.auctions(1);

        skip(60 * 60 * 24 * 7 - 59 * 59); // 1 second before auction ends

        market.bid{value: 0.06 ether}(1);

        (,, uint256 endTimeB,,,,) = market.auctions(1);

        assertLt(endTimeA, endTimeB, "New endtime should be greater than old endtime");
    }

    function test_bid_RevertIf_BelowMinimumIncrement() public {
        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        vm.expectRevert(bytes4(keccak256("BidTooLow()")));
        market.bid{value: 0.055 ether}(1);
    }

    function test_bid_RevertIf_BidEqualsHighestBid() public {
        vm.startPrank(user1);

        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        uint256 auctionId = market.nextAuctionId() - 1;

        market.bid{value: 0.06 ether}(auctionId);
        vm.expectRevert(bytes4(keccak256("BidTooLow()")));
        market.bid{value: 0.06 ether}(auctionId);
    }

    function test_bid_RevertIf_AfterAuctionEnded() public {
        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        skip(60 * 60 * 24 * 7 + 1);
        vm.expectRevert(bytes4(keccak256("AuctionEnded()")));
        market.bid{value: 0.06 ether}(1);
    }

    function testFuzz_bid_Success(uint256 bidA, uint256 bidB) public {
        uint256 _bidA = bound(bidA, 0.05 ether, 1000 ether);
        uint256 _bidB = bound(bidB, _bidA + market.minBidIncrement(), type(uint256).max);
        vm.assume(_bidB > _bidA && user1.balance >= _bidA && user2.balance >= _bidB);

        vm.prank(user1);
        market.startAuctionERC721{value: _bidA}(address(mock721), tokenIds);

        vm.prank(user2);
        market.bid{value: _bidB}(1);
        assertEq(bidTicket.balanceOf(user1, 1), 95);
        assertEq(bidTicket.balanceOf(user2, 1), 99);

        (,,,,, address highestBidder, uint256 highestBid) = market.auctions(1);

        assertEq(highestBidder, user2, "Highest bidder should be this contract");
        assertEq(highestBid, _bidB, "Highest bid should be 0.06 ether");
    }

    //
    // claim()
    //
    function test_claim_Success_ERC721() public {
        vm.startPrank(user1);

        uint256 auctionId = market.nextAuctionId();
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        assertEq(user1.balance, 0.95 ether, "user1 should have 0.95 after starting the auction");

        vm.startPrank(user2);
        market.bid{value: 0.06 ether}(auctionId);

        (,,,,, address highestBidder, uint256 highestBid) = market.auctions(auctionId);

        assertEq(user1.balance, 1 ether, "user1 should have 1 ether again");
        assertEq(user2.balance, 0.94 ether, "user2 should have 0.95 ether");
        assertEq(highestBidder, user2, "Highest bidder should be user1");
        assertEq(highestBid, 0.06 ether, "Highest bid should be 0.06 ether");

        skip(60 * 60 * 24 * 7 + 1);
        market.claim(auctionId);

        assertEq(mock721.ownerOf(tokenIds[0]), user2, "Should own token 0");
        assertEq(mock721.ownerOf(tokenIds[1]), user2, "Should own token 1");
        assertEq(mock721.ownerOf(tokenIds[2]), user2, "Should own token 2");
    }

    function test_claim_Success_ERC1155() public {
        vm.startPrank(user1);

        assertEq(mock1155.balanceOf(theBarn, tokenIds[0]), 10, "Should own token 0");
        assertEq(mock1155.balanceOf(theBarn, tokenIds[1]), 10, "Should own token 1");
        assertEq(mock1155.balanceOf(theBarn, tokenIds[2]), 10, "Should own token 2");
        assertEq(mock1155.isApprovedForAll(theBarn, address(market)), true, "Should be approved for all");

        uint256 auctionId = market.nextAuctionId();
        market.startAuctionERC1155{value: 0.05 ether}(address(mock1155), tokenIds, amounts);
        assertEq(user1.balance, 0.95 ether, "user1 should have 0.95 after starting the auction");

        vm.startPrank(user2);
        market.bid{value: 0.06 ether}(auctionId);

        (,,,,, address highestBidder, uint256 highestBid) = market.auctions(auctionId);

        assertEq(user1.balance, 1 ether, "user1 should have 1 ether again");
        assertEq(user2.balance, 0.94 ether, "user2 should have 0.95 ether");
        assertEq(highestBidder, user2, "Highest bidder should be user1");
        assertEq(highestBid, 0.06 ether, "Highest bid should be 0.06 ether");

        skip(60 * 60 * 24 * 7 + 1);
        market.claim(auctionId);

        assertEq(mock1155.balanceOf(user2, tokenIds[0]), 1, "Should own token 0");
        assertEq(mock1155.balanceOf(user2, tokenIds[1]), 1, "Should own token 1");
        assertEq(mock1155.balanceOf(user2, tokenIds[2]), 1, "Should own token 2");
    }

    function test_claim_RevertIf_BeforeAuctionEnded() public {
        vm.startPrank(user1);

        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        vm.expectRevert(bytes4(keccak256("AuctionNotEnded()")));
        market.claim(1);
    }

    function test_claim_RevertIf_NotHighestBidder() public {
        vm.startPrank(user1);

        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        skip(60 * 60 * 24 * 7 + 1);

        vm.startPrank(user2);
        vm.expectRevert(bytes4(keccak256("NotHighestBidder()")));
        market.claim(1);
    }

    function test_claim_RevertIf_AbandonedAuction() public {
        uint256 auctionId = market.nextAuctionId();

        vm.prank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        skip(60 * 60 * 24 * 14 + 1);

        market.abandon(auctionId);

        vm.prank(user1);
        vm.expectRevert(bytes4(keccak256("AuctionAbandoned()")));
        market.claim(auctionId);
    }

    function test_claim_RevertIf_AuctionRefunded() public {
        vm.prank(theBarn);
        mock721.setApprovalForAll(address(market), false);
        uint256 auctionId = market.nextAuctionId();

        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        skip(60 * 60 * 24 * 7 + 1);

        market.refund(auctionId);
        vm.expectRevert(bytes4(keccak256("AuctionRefunded()")));
        market.claim(auctionId);
    }

    function test_claim_RevertIf_AuctionClaimed() public {
        uint256 auctionId = market.nextAuctionId();

        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        skip(60 * 60 * 24 * 7 + 1);

        market.claim(auctionId);
        vm.expectRevert(bytes4(keccak256("AuctionClaimed()")));
        market.claim(auctionId);
    }

    //
    // refund
    //
    function test_refund_Success_ERC721() public {
        uint256 auctionId = market.nextAuctionId();
        market.setMaxTokens(50);
        vm.prank(theBarn);
        mock721.setApprovalForAll(address(market), false);

        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        assertEq(user1.balance, 1 ether - 0.05 ether, "user1 should have 0.05 less");
        assertTrue(market.auctionTokensERC721(address(mock721), tokenIds[0]), "Token 0 should not be in auction");
        assertTrue(market.auctionTokensERC721(address(mock721), tokenIds[1]), "Token 1 should not be in auction");
        assertTrue(market.auctionTokensERC721(address(mock721), tokenIds[2]), "Token 2 should not be in auction");

        skip(60 * 60 * 24 * 7 + 1);

        market.refund(auctionId);
        assertEq(user1.balance, 1 ether, "user1 should have 1 ether again");

        (,,,, Status status,,) = market.auctions(auctionId);

        assertTrue(status == Status.Refunded, "Auction should be marked as refunded");
        assertFalse(market.auctionTokensERC721(address(mock721), tokenIds[0]), "Token 0 should not be in auction");
        assertFalse(market.auctionTokensERC721(address(mock721), tokenIds[1]), "Token 1 should not be in auction");
        assertFalse(market.auctionTokensERC721(address(mock721), tokenIds[2]), "Token 2 should not be in auction");
    }

    function test_refund_Success_ERC1155() public {
        uint256 auctionId = market.nextAuctionId();
        market.setMaxTokens(50);
        vm.prank(theBarn);
        mock1155.setApprovalForAll(address(market), false);

        vm.startPrank(user1);
        market.startAuctionERC1155{value: 0.05 ether}(address(mock1155), tokenIds, tokenIdAmounts);

        assertEq(user1.balance, 1 ether - 0.05 ether, "user1 should have 0.05 less");
        assertEq(market.auctionTokensERC1155(address(mock1155), tokenIds[0]), 10, "Token 0 should have 10 in auction");
        assertEq(market.auctionTokensERC1155(address(mock1155), tokenIds[1]), 10, "Token 1 should have 10 in auction");
        assertEq(market.auctionTokensERC1155(address(mock1155), tokenIds[2]), 10, "Token 2 should have 10 in auction");

        skip(60 * 60 * 24 * 7 + 1);

        market.refund(auctionId);
        assertEq(user1.balance, 1 ether, "user1 should have 1 ether again");

        (,,,, Status status,,) = market.auctions(auctionId);

        assertTrue(status == Status.Refunded, "Auction should be marked as refunded");
        assertEq(market.auctionTokensERC1155(address(mock1155), tokenIds[0]), 0, "Token 0 should have 0 in auction");
        assertEq(market.auctionTokensERC1155(address(mock1155), tokenIds[1]), 0, "Token 1 should have 0 in auction");
        assertEq(market.auctionTokensERC1155(address(mock1155), tokenIds[2]), 0, "Token 2 should have 0 in auction");
    }

    function test_refund_RevertIf_AuctionActive() public {
        vm.prank(theBarn);
        mock721.setApprovalForAll(address(market), false);

        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        vm.expectRevert(bytes4(keccak256("AuctionActive()")));
        market.refund(1);
    }

    function test_refund_RevertIf_SettlementPeriodEnded() public {
        vm.prank(theBarn);
        mock721.setApprovalForAll(address(market), false);

        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        skip(60 * 60 * 24 * 14 + 1);

        vm.expectRevert(bytes4(keccak256("SettlementPeriodEnded()")));
        market.refund(1);
    }

    function test_refund_RevertIf_NotHighestBidder() public {
        vm.prank(theBarn);
        mock721.setApprovalForAll(address(market), false);

        vm.prank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        skip(60 * 60 * 24 * 7 + 1);

        vm.prank(user2);
        vm.expectRevert(bytes4(keccak256("NotHighestBidder()")));
        market.refund(1);
    }

    function test_refund_RevertIf_AuctionRefunded() public {
        uint256 auctionId = market.nextAuctionId();
        vm.prank(theBarn);
        mock721.setApprovalForAll(address(market), false);

        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        skip(60 * 60 * 24 * 7 + 1);

        market.refund(auctionId);
        vm.expectRevert(bytes4(keccak256("AuctionRefunded()")));
        market.refund(auctionId);
    }

    function test_refund_RevertIf_AuctionClaimed() public {
        uint256 auctionId = market.nextAuctionId();

        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        skip(60 * 60 * 24 * 7 + 1);

        market.claim(auctionId);
        vm.expectRevert(bytes4(keccak256("AuctionClaimed()")));
        market.refund(auctionId);
    }

    //
    // abandon
    //
    function test_abandon_Success_ERC721() public {
        uint256 auctionId = market.nextAuctionId();
        uint256 startingBid = 0.05 ether;

        vm.prank(user1);
        market.startAuctionERC721{value: startingBid}(address(mock721), tokenIds);

        assertEq(user1.balance, 0.95 ether, "user1 should have 0.95 after starting the auction");
        assertTrue(market.auctionTokensERC721(address(mock721), tokenIds[0]), "Token 0 should not be in auction");
        assertTrue(market.auctionTokensERC721(address(mock721), tokenIds[1]), "Token 1 should not be in auction");
        assertTrue(market.auctionTokensERC721(address(mock721), tokenIds[2]), "Token 2 should not be in auction");

        skip(60 * 60 * 24 * 14 + 1);

        vm.startPrank(address(this));
        market.abandon(auctionId);

        assertEq(
            user1.balance,
            1 ether - startingBid * market.ABANDONMENT_FEE_PERCENT() / 100,
            "user1 should have 1 ether - fee"
        );

        (,,,, Status status,,) = market.auctions(auctionId);

        assertTrue(status == Status.Abandoned, "Auction should be marked as abandoned");
        assertFalse(market.auctionTokensERC721(address(mock721), tokenIds[0]), "Token 0 should not be in auction");
        assertFalse(market.auctionTokensERC721(address(mock721), tokenIds[1]), "Token 1 should not be in auction");
        assertFalse(market.auctionTokensERC721(address(mock721), tokenIds[2]), "Token 2 should not be in auction");
    }

    function test_abandon_Success_ERC1155() public {
        uint256 auctionId = market.nextAuctionId();
        uint256 startingBid = 0.05 ether;
        market.setMaxTokens(50);

        vm.prank(user1);
        market.startAuctionERC1155{value: startingBid}(address(mock1155), tokenIds, tokenIdAmounts);

        assertEq(user1.balance, 0.95 ether, "user1 should have 0.95 after starting the auction");
        assertEq(market.auctionTokensERC1155(address(mock1155), tokenIds[0]), 10, "Token 0 should have 10 in auction");
        assertEq(market.auctionTokensERC1155(address(mock1155), tokenIds[1]), 10, "Token 1 should have 10 in auction");
        assertEq(market.auctionTokensERC1155(address(mock1155), tokenIds[2]), 10, "Token 2 should have 10 in auction");

        skip(60 * 60 * 24 * 14 + 1);

        vm.startPrank(address(this));
        market.abandon(auctionId);

        assertEq(
            user1.balance,
            1 ether - startingBid * market.ABANDONMENT_FEE_PERCENT() / 100,
            "user1 should have 1 ether - fee"
        );

        (,,,, Status status,,) = market.auctions(auctionId);

        assertTrue(status == Status.Abandoned, "Auction should be marked as abandoned");
        assertEq(market.auctionTokensERC1155(address(mock1155), tokenIds[0]), 0, "Token 0 should have 0 in auction");
        assertEq(market.auctionTokensERC1155(address(mock1155), tokenIds[1]), 0, "Token 1 should have 0 in auction");
        assertEq(market.auctionTokensERC1155(address(mock1155), tokenIds[2]), 0, "Token 2 should have 0 in auction");
    }

    function test_abandon_RevertIf_AuctionActive() public {
        vm.prank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        vm.expectRevert(bytes4(keccak256("SettlementPeriodNotExpired()")));
        market.abandon(1);
    }

    function test_abandon_RevertIf_SettlementPeriodActive() public {
        vm.prank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        skip(60 * 60 * 24 * 7 + 1);

        vm.expectRevert(bytes4(keccak256("SettlementPeriodNotExpired()")));
        market.abandon(1);
    }

    function test_abandon_RevertIf_AuctionAbandoned() public {
        vm.prank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        skip(60 * 60 * 24 * 14 + 1);

        market.abandon(1);
        vm.expectRevert(bytes4(keccak256("AuctionAbandoned()")));
        market.abandon(1);
    }

    function test_abandon_RevertIf_AuctionRefunded() public {
        vm.prank(theBarn);
        mock721.setApprovalForAll(address(market), false);

        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        skip(60 * 60 * 24 * 7 + 1);
        market.refund(1);
        vm.stopPrank();

        skip(60 * 60 * 24 * 7);

        vm.expectRevert(bytes4(keccak256("AuctionRefunded()")));
        market.abandon(1);
    }

    function test_abandon_RevertIf_AuctionClaimed() public {
        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        skip(60 * 60 * 24 * 14 + 1);
        market.claim(1);
        vm.stopPrank();

        vm.expectRevert(bytes4(keccak256("AuctionClaimed()")));
        market.abandon(1);
    }

    //
    // withdraw
    //
    function test_withdraw_Success() public {
        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        uint256 auctionId = market.nextAuctionId() - 1;
        uint256[] memory auctionIds = new uint256[](1);
        auctionIds[0] = auctionId;

        skip(60 * 60 * 24 * 14 + 1); // the settlement period has ended
        market.claim(auctionId);

        vm.startPrank(address(this));
        market.withdraw(auctionIds);

        (,,,, Status status,,) = market.auctions(auctionId);
        assertTrue(status == Status.Withdrawn, "Auction should be marked as withdrawn");
    }

    function test_withdraw_RevertIf_ActiveAuction() public {
        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        uint256 auctionId = market.nextAuctionId() - 1;
        uint256[] memory auctionIds = new uint256[](1);
        auctionIds[0] = auctionId;

        skip(60 * 60 * 24 * 1); // auction is still active

        vm.startPrank(address(this));
        vm.expectRevert(bytes4(keccak256("AuctionNotClaimed()")));
        market.withdraw(auctionIds);
    }

    function test_withdraw_RevertIf_SettlementPeriodActive() public {
        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        uint256 auctionId = market.nextAuctionId() - 1;
        uint256[] memory auctionIds = new uint256[](1);
        auctionIds[0] = auctionId;

        skip(60 * 60 * 24 * 7 + 1); // beginning of the settlement period

        vm.startPrank(address(this));
        vm.expectRevert(bytes4(keccak256("AuctionNotClaimed()")));
        market.withdraw(auctionIds);
    }

    function test_withdraw_RevertIf_AuctionWithdrawn() public {
        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        uint256 auctionId = market.nextAuctionId() - 1;
        uint256[] memory auctionIds = new uint256[](1);
        auctionIds[0] = auctionId;

        skip(60 * 60 * 24 * 7 + 1); // the settlement period has started
        market.claim(auctionId);

        skip(60 * 60 * 24 * 14 + 1); // the settlement period has ended
        vm.startPrank(address(this));
        market.withdraw(auctionIds);
        vm.expectRevert(bytes4(keccak256("AuctionNotClaimed()")));
        market.withdraw(auctionIds);
    }

    function test_withdraw_RevertIf_AuctionNotClaimed() public {
        vm.prank(theBarn);
        mock721.setApprovalForAll(address(market), false);
        uint256 auctionId = market.nextAuctionId();

        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        skip(60 * 60 * 24 * 7 + 1);
        market.refund(auctionId);
        vm.stopPrank();

        uint256[] memory auctionIds = new uint256[](1);
        auctionIds[0] = auctionId;
        vm.expectRevert(bytes4(keccak256("AuctionNotClaimed()")));
        market.withdraw(auctionIds);
    }

    function test_withdraw_RevertIf_AuctionAbandoned() public {
        uint256 auctionId = market.nextAuctionId();

        vm.prank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        skip(60 * 60 * 24 * 14 + 1);

        market.abandon(auctionId);

        uint256[] memory auctionIds = new uint256[](1);
        auctionIds[0] = auctionId;
        vm.expectRevert(bytes4(keccak256("AuctionNotClaimed()")));
        market.withdraw(auctionIds);
    }

    //
    // getters/setters
    //
    function test_getAuctionTokens_Success_ERC721() public {
        market.setMaxTokens(50);

        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        (, address tokenAddress,,,,,) = market.auctions(1);
        assertEq(tokenAddress, address(mock721));

        (uint256[] memory _tokenIds, uint256[] memory _amounts) = market.getAuctionTokens(1);

        assertEq(_tokenIds[0], tokenIds[0]);
        assertEq(_tokenIds[1], tokenIds[1]);
        assertEq(_tokenIds[2], tokenIds[2]);
        assertEq(_amounts[0], amounts[0]);
        assertEq(_amounts[1], amounts[1]);
        assertEq(_amounts[2], amounts[2]);
    }

    function test_getAuctionTokens_Success_ERC1155() public {
        market.setMaxTokens(50);
        vm.startPrank(user1);
        market.startAuctionERC1155{value: 0.05 ether}(address(mock1155), tokenIds, tokenIdAmounts);

        (, address tokenAddress,,,,,) = market.auctions(1);
        assertEq(tokenAddress, address(mock1155));

        (uint256[] memory _tokenIds, uint256[] memory _amounts) = market.getAuctionTokens(1);

        assertEq(_tokenIds[0], tokenIds[0]);
        assertEq(_tokenIds[1], tokenIds[1]);
        assertEq(_tokenIds[2], tokenIds[2]);
        assertEq(_amounts[0], tokenIdAmounts[0]);
        assertEq(_amounts[1], tokenIdAmounts[1]);
        assertEq(_amounts[2], tokenIdAmounts[2]);
    }

    function test_setMinStartPrice_Success() public {
        market.setMinStartPrice(0.01 ether);

        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.01 ether}(address(mock721), tokenIds);
    }

    function test_setMintBidIncrement_Success() public {
        market.setMinBidIncrement(0.02 ether);

        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        market.bid{value: 0.07 ether}(1);
        market.bid{value: 0.09 ether}(1);
    }

    function test_setMinBidIncrement_RevertIf_BidTooLow() public {
        market.setMinBidIncrement(0.02 ether);

        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        market.bid{value: 0.07 ether}(1);
        vm.expectRevert(bytes4(keccak256("BidTooLow()")));
        market.bid{value: 0.08 ether}(1);
    }

    function test_setBarnAddress_Success() public {
        market.setBarnAddress(vm.addr(420));
    }

    function test_setBarnAddress_RevertIf_NotOwner() public {
        vm.prank(vm.addr(69));
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        market.setBarnAddress(vm.addr(420));
    }

    function test_setBidTicketAddress_Success() public {
        market.setBidTicketAddress(vm.addr(420));
    }

    function test_setBidTicketAddress_RevertIf_NotOwner() public {
        vm.prank(vm.addr(69));
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        market.setBidTicketAddress(vm.addr(420));
    }

    function test_setBidTicketTokenId_Success() public {
        market.setBidTicketTokenId(255);
    }

    function test_setBidTicketTokenId_RevertIf_NotOwner() public {
        vm.prank(vm.addr(69));
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        market.setBidTicketTokenId(255);
    }

    function test_setMaxTokens_Success() public {
        market.setMaxTokens(255);
    }

    function test_setMaxTokens_RevertIf_NotOwner() public {
        vm.prank(vm.addr(69));
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        market.setMaxTokens(255);
    }

    function test_setAuctionDuration_Success() public {
        market.setAuctionDuration(60 * 60 * 24 * 7);
    }

    function test_setAuctionDuration_RevertIf_NotOwner() public {
        vm.prank(vm.addr(69));
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        market.setAuctionDuration(60 * 60 * 24 * 7);
    }

    function test_setSettlementDuration_Success() public {
        market.setSettlementDuration(60 * 60 * 24 * 7);
    }

    function test_setSettlementDuration_RevertIf_NotOwner() public {
        vm.prank(vm.addr(69));
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        market.setSettlementDuration(60 * 60 * 24 * 7);
    }
}
