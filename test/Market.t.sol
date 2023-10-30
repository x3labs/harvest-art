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
    // startAuction()
    //
    function test_StartAuction() public {
        vm.startPrank(user1);

        uint256 startBalance = user1.balance;
        assertEq(bidTicket.balanceOf(user1, 1), 100);

        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        assertEq(user1.balance, startBalance - 0.05 ether, "Balance should decrease by 0.05 ether");
        assertEq(market.nextAuctionId(), 2, "nextAuctionId should be incremented");
        assertEq(bidTicket.balanceOf(user1, 1), 95);

        (, address tokenAddress,,,,,,, address highestBidder, uint256 highestBid) = market.auctions(1);

        assertEq(tokenAddress, address(mock721));
        assertEq(highestBidder, user1);
        assertEq(highestBid, 0.05 ether);
    }

    function testFuzz_StartAuction(uint256 bidAmount) public {
        vm.assume(bidAmount > 0.05 ether);
        vm.assume(user1.balance >= bidAmount);

        vm.startPrank(user1);

        uint256 startBalance = user1.balance;
        assertEq(bidTicket.balanceOf(user1, 1), 100);

        market.startAuctionERC721{value: bidAmount}(address(mock721), tokenIds);
        assertEq(user1.balance, startBalance - bidAmount, "Balance should decrease by bid amount");
        assertEq(market.nextAuctionId(), 2, "nextAuctionId should be incremented");
        assertEq(bidTicket.balanceOf(user1, 1), 95);

        (, address tokenAddress,,,,,,, address highestBidder, uint256 highestBid) = market.auctions(1);

        assertEq(tokenAddress, address(mock721));
        assertEq(highestBidder, user1);
        assertEq(highestBid, bidAmount);
    }

    function test_StartAuctionForERC1155() public {
        vm.startPrank(user1);

        uint256 startBalance = user1.balance;
        assertEq(bidTicket.balanceOf(user1, 1), 100);

        market.startAuctionERC1155{value: 0.05 ether}(address(mock1155), tokenIds, amounts);
        assertEq(user1.balance, startBalance - 0.05 ether, "Balance should decrease by 0.05 ether");
        assertEq(market.nextAuctionId(), 2, "nextAuctionId should be incremented");
        assertEq(bidTicket.balanceOf(user1, 1), 95);

        (, address tokenAddress,,,,,,, address highestBidder, uint256 highestBid) = market.auctions(1);

        assertEq(tokenAddress, address(mock1155));
        assertEq(highestBidder, user1);
        assertEq(highestBid, 0.05 ether);
    }

    function test_StartAuctionWithTooManyTokens() public {
        vm.startPrank(user1);

        uint256[] memory manyTokenIds = new uint256[](1001);

        try market.startAuctionERC721{value: 0.05 ether}(address(mock721), manyTokenIds) {
            fail("Should not allow creating an auction with too many tokens");
        } catch {}

        uint256 nextAuctionId = market.nextAuctionId();
        assertEq(nextAuctionId, 1, "nextAuctionId should remain unchanged");
    }

    function test_StartAuctionWithResetTokenTracker() public {
        vm.startPrank(user1);

        uint256 nextAuctionId = market.nextAuctionId();

        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        skip(60 * 60 * 24 * 7 + 1);
        market.claim(nextAuctionId);

        mock721.transferFrom(user1, theBarn, tokenIds[0]);
        mock721.transferFrom(user1, theBarn, tokenIds[1]);
        mock721.transferFrom(user1, theBarn, tokenIds[2]);

        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        assertEq(market.nextAuctionId(), nextAuctionId + 2, "nextAuctionId should be incremented");
    }

    function test_StartAuctionWithLowStartPrice() public {
        vm.startPrank(user1);

        try market.startAuctionERC721{value: 0.04 ether}(address(mock721), tokenIds) {
            fail("Should not allow creating an auction with a start price below the minimum");
        } catch {}

        uint256 nextAuctionId = market.nextAuctionId();
        assertEq(nextAuctionId, 1, "nextAuctionId should remain unchanged");
    }

    function testFail_StartAuctionWithoutEnoughBidTickets() public {
        vm.startPrank(user1);
        bidTicket.burn(user1, 1, 100);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
    }

    function testFail_StartAuctionWithOverlappingTokens() public {
        vm.startPrank(user1);

        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
    }

    //
    // bid()
    //
    function test_Bid() public {
        vm.startPrank(user1);
        assertEq(bidTicket.balanceOf(user1, 1), 100);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        assertEq(bidTicket.balanceOf(user1, 1), 95);
        vm.stopPrank();

        vm.startPrank(user2);
        market.bid{value: 0.06 ether}(1);
        assertEq(bidTicket.balanceOf(user1, 1), 95);
        assertEq(bidTicket.balanceOf(user2, 1), 99);

        (,,,,,,,, address highestBidder, uint256 highestBid) = market.auctions(1);

        assertEq(highestBidder, user2, "Highest bidder should be this contract");
        assertEq(highestBid, 0.06 ether, "Highest bid should be 0.06 ether");
    }

    function test_BidSelf() public {
        vm.startPrank(user1);

        assertEq(bidTicket.balanceOf(user1, 1), 100);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        assertEq(bidTicket.balanceOf(user1, 1), 95);
        market.bid{value: 0.06 ether}(1);
        assertEq(bidTicket.balanceOf(user1, 1), 94);

        (,,,,,,,, address highestBidder, uint256 highestBid) = market.auctions(1);

        assertEq(highestBidder, user1, "Highest bidder should be this contract");
        assertEq(highestBid, 0.06 ether, "Highest bid should be 0.06 ether");
    }

    function test_BidBelowMinimumIncrement() public {
        vm.startPrank(user1);

        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        try market.bid{value: 0.055 ether}(1) {
            fail("Should not allow bids below the minimum increment");
        } catch {}

        (,,,,,,,,, uint256 highestBid) = market.auctions(1);
        assertEq(highestBid, 0.05 ether, "Highest bid should remain 0.05 ether");
    }

    function test_BidRevertOnEqualBid() public {
        vm.startPrank(user1);

        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        uint256 auctionId = market.nextAuctionId() - 1;

        market.bid{value: 0.06 ether}(auctionId);

        try market.bid{value: 0.06 ether}(auctionId) {
            fail("Should have reverted on equal bid");
        } catch {}
    }

    function test_BidAfterAuctionEnded() public {
        vm.startPrank(user1);

        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        skip(60 * 60 * 24 * 7 + 1);

        try market.bid{value: 0.06 ether}(1) {
            fail("Should not allow bids after the auction has ended");
        } catch {}

        (,,,,,,,,, uint256 highestBid) = market.auctions(1);
        assertEq(highestBid, 0.05 ether, "Highest bid should remain 0.05 ether");
    }

    function testFuzz_Bid(uint256 bidA, uint256 bidB) public {
        uint256 _bidA = bound(bidA, 0.05 ether, 1000 ether);
        uint256 _bidB = bound(bidB, _bidA + market.minBidIncrement(), type(uint256).max);
        vm.assume(_bidB > _bidA && user1.balance >= _bidA && user2.balance >= _bidB);

        vm.prank(user1);
        market.startAuctionERC721{value: _bidA}(address(mock721), tokenIds);

        vm.prank(user2);
        market.bid{value: _bidB}(1);
        assertEq(bidTicket.balanceOf(user1, 1), 95);
        assertEq(bidTicket.balanceOf(user2, 1), 99);

        (,,,,,,,, address highestBidder, uint256 highestBid) = market.auctions(1);

        assertEq(highestBidder, user2, "Highest bidder should be this contract");
        assertEq(highestBid, _bidB, "Highest bid should be 0.06 ether");
    }

    //
    // claim()
    //
    function test_Claim() public {
        vm.startPrank(user1);

        uint256 auctionId = market.nextAuctionId();
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);
        assertEq(user1.balance, 0.95 ether, "user1 should have 0.95 after starting the auction");

        vm.startPrank(user2);
        market.bid{value: 0.06 ether}(auctionId);

        (,,,,,,,, address highestBidder, uint256 highestBid) = market.auctions(auctionId);

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

    function test_ClaimBeforeAuctionEnded() public {
        vm.startPrank(user1);

        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        try market.claim(1) {
            fail("Should not allow claiming before the auction has ended");
        } catch {}

        (,,,,,,,, address highestBidder,) = market.auctions(1);
        assertEq(highestBidder, user1, "Highest bidder should remain unchanged");
    }

    function test_ClaimByNonHighestBidder() public {
        vm.startPrank(user1);

        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        skip(60 * 60 * 24 * 7 + 1);

        vm.startPrank(user2);

        try market.claim(1) {
            fail("Should not allow non-highest bidders to claim");
        } catch {}

        vm.stopPrank();

        (,,,,,,,, address highestBidder,) = market.auctions(1);
        assertEq(highestBidder, user1, "Highest bidder should remain unchanged");
    }

    function test_ClaimRevertWhenAbandonedAuction() public {
        vm.startPrank(user1);

        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        skip(60 * 60 * 24 * 14 + 1);

        vm.startPrank(address(this));

        try market.claim(1) {
            fail("Should not allow claiming abandoned auctions");
        } catch {}
    }

    //
    // withdraw()
    //
    function test_WithdrawSuccessful() public {
        vm.startPrank(user1);

        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        uint256 auctionId = market.nextAuctionId() - 1;
        uint256[] memory auctionIds = new uint256[](1);
        auctionIds[0] = auctionId;

        skip(60 * 60 * 24 * 14 + 1); // the settlement period has ended

        vm.startPrank(address(this));
        market.withdraw(auctionIds);

        (,,,,, bool withdrawn,,,,) = market.auctions(auctionId);
        assertTrue(withdrawn, "Auction should be marked as withdrawn");
    }

    function test_WithdrawRevertOnActiveAuction() public {
        vm.startPrank(user1);

        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        uint256 auctionId = market.nextAuctionId() - 1;
        uint256[] memory auctionIds = new uint256[](1);
        auctionIds[0] = auctionId;

        skip(60 * 60 * 24 * 1); // auction is still active

        vm.startPrank(address(this));

        try market.withdraw(auctionIds) {
            fail("Should have reverted on active auction withdrawal");
        } catch {}
    }

    function test_WithdrawRevertDuringSettlementPeriod() public {
        vm.startPrank(user1);

        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        uint256 auctionId = market.nextAuctionId() - 1;
        uint256[] memory auctionIds = new uint256[](1);
        auctionIds[0] = auctionId;

        skip(60 * 60 * 24 * 7 + 1); // beginning of the settlement period

        vm.startPrank(address(this));

        try market.withdraw(auctionIds) {
            fail("Should have reverted withdrawal during settlement period");
        } catch {}
    }

    function test_WithdrawRevertOnAlreadyWithdrawnAuction() public {
        vm.startPrank(user1);

        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        uint256 auctionId = market.nextAuctionId() - 1;
        uint256[] memory auctionIds = new uint256[](1);
        auctionIds[0] = auctionId;

        skip(60 * 60 * 24 * 14 + 1); // the settlement period has ended

        vm.startPrank(address(this));
        market.withdraw(auctionIds);

        try market.withdraw(auctionIds) {
            fail("Should have reverted on already withdrawn auction");
        } catch {}
    }

    //
    // getters/setters
    //
    function test_GetAuctionTokens() public {
        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        (, address tokenAddress,,,,,,,,) = market.auctions(1);
        assertEq(tokenAddress, address(mock721));

        (uint256[] memory _tokenIds, uint256[] memory _amounts) = market.getAuctionTokens(1);

        assertEq(_tokenIds[0], tokenIds[0]);
        assertEq(_tokenIds[1], tokenIds[1]);
        assertEq(_tokenIds[2], tokenIds[2]);
        assertEq(_amounts[0], amounts[0]);
        assertEq(_amounts[1], amounts[1]);
        assertEq(_amounts[2], amounts[2]);
    }

    function test_SetMinStartPrice() public {
        market.setMinStartPrice(0.01 ether);

        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.01 ether}(address(mock721), tokenIds);
    }

    function test_SetMinBidIncrement() public {
        market.setMinBidIncrement(0.02 ether);

        vm.startPrank(user1);
        market.startAuctionERC721{value: 0.05 ether}(address(mock721), tokenIds);

        market.bid{value: 0.07 ether}(1);

        try market.bid{value: 0.08 ether}(1) {
            fail("Should not allow bids below the minimum increment");
        } catch {}
    }

    function test_SetBarnAddress() public {
        market.setBarnAddress(vm.addr(420));
    }

    function testFail_SetBarnAddressByNonOwner() public {
        vm.prank(vm.addr(69));
        market.setBarnAddress(vm.addr(420));
    }

    function test_SetBidTicketAddress() public {
        market.setBidTicketAddress(vm.addr(420));
    }

    function testFail_SetBidTicketAddressByNonOwner() public {
        vm.prank(vm.addr(69));
        market.setBidTicketAddress(vm.addr(420));
    }

    function test_SetBidTicketTokenId() public {
        market.setBidTicketTokenId(255);
    }

    function testFail_SetBidTicketTokenIdByNonOwner() public {
        vm.prank(vm.addr(69));
        market.setBidTicketTokenId(255);
    }

    function test_SetMaxTokens() public {
        market.setMaxTokens(255);
    }

    function testFail_SetMaxTokensByNonOwner() public {
        vm.prank(vm.addr(69));
        market.setMaxTokens(255);
    }

    function test_SetAuctionDuration() public {
        market.setAuctionDuration(60 * 60 * 24 * 7);
    }

    function testFail_SetAuctionDurationByNonOwner() public {
        vm.prank(vm.addr(69));
        market.setAuctionDuration(60 * 60 * 24 * 7);
    }

    function test_SetSettlementDuration() public {
        market.setSettlementDuration(60 * 60 * 24 * 7);
    }

    function testFail_SetSettlementDurationByNonOwner() public {
        vm.prank(vm.addr(69));
        market.setSettlementDuration(60 * 60 * 24 * 7);
    }

    function test_SetAbandonmentFeePercent() public {
        market.setAbandonmentFeePercent(10);
    }

    function testFail_SetAbandonmentFeePercentByNonOwner() public {
        vm.prank(vm.addr(69));
        market.setAbandonmentFeePercent(10);
    }
}
