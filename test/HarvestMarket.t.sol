// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/HarvestMarket.sol";
import "../src/BidTicket.sol";
import "./Mock721.sol";

contract HarvestMarketTest is Test {
    HarvestMarket public market;
    BidTicket public bidTicket;
    Mock721 public mock721;
    address public theBarn;
    address public user1;
    address public user2;
    uint256 public tokenCount = 10;
    uint256[] public tokenIds = [0, 1, 2];
    uint8[] public amounts = [1, 1, 1];

    receive() external payable {}
    fallback() external payable {}

    function setUp() public {
        theBarn = vm.addr(1);
        bidTicket = new BidTicket();
        market = new HarvestMarket(theBarn, address(bidTicket));
        mock721 = new Mock721();

        user1 = vm.addr(2);
        user2 = vm.addr(3);

        bidTicket.setMarketContract(address(market));
        bidTicket.mint(user1, 1, 100, "");
        bidTicket.mint(user2, 1, 100, "");

        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);

        mock721.mint(theBarn, tokenCount);
        vm.prank(theBarn);
        mock721.setApprovalForAll(address(market), true);
    }

    //
    // startAuction()
    //
    function testStartAuction() public {
        vm.startPrank(user1);

        uint256 startBalance = user1.balance;
        assertEq(bidTicket.balanceOf(user1, 1), 100);

        market.startAuction{value: 0.05 ether}(address(mock721), tokenIds, amounts);
        assertEq(user1.balance, startBalance - 0.05 ether, "Balance should decrease by 0.05 ether");
        assertEq(market.nextAuctionId(), 2, "nextAuctionId should be incremented");
        assertEq(bidTicket.balanceOf(user1, 1), 95);

        (address tokenAddress, address highestBidder, uint256 highestBid,,,) = market.auctions(1);

        assertEq(tokenAddress, address(mock721));
        assertEq(highestBidder, user1);
        assertEq(highestBid, 0.05 ether);
    }

    function testStartAuctionWithTooManyTokens() public {
        vm.startPrank(user1);

        uint256[] memory manyTokenIds = new uint256[](1001);
        uint8[] memory manyAmounts = new uint8[](1001);

        try market.startAuction{value: 0.05 ether}(address(mock721), manyTokenIds, manyAmounts) {
            fail("Should not allow creating an auction with too many tokens");
        } catch {}

        uint256 nextAuctionId = market.nextAuctionId();
        assertEq(nextAuctionId, 1, "nextAuctionId should remain unchanged");
    }

    function testStartAuctionWithResetTokenTracker() public {
        vm.startPrank(user1);

        uint256 nextAuctionId = market.nextAuctionId();

        market.startAuction{value: 0.05 ether}(address(mock721), tokenIds, amounts);
        skip(60 * 60 * 24 * 7 + 1);
        market.claim(nextAuctionId);

        mock721.transferFrom(user1, theBarn, tokenIds[0]);
        mock721.transferFrom(user1, theBarn, tokenIds[1]);
        mock721.transferFrom(user1, theBarn, tokenIds[2]);

        market.startAuction{value: 0.05 ether}(address(mock721), tokenIds, amounts);
        assertEq(market.nextAuctionId(), nextAuctionId + 2, "nextAuctionId should be incremented");
    }

    function testStartAuctionWithLowStartPrice() public {
        vm.startPrank(user1);

        try market.startAuction{value: 0.04 ether}(address(mock721), tokenIds, amounts) {
            fail("Should not allow creating an auction with a start price below the minimum");
        } catch {}

        uint256 nextAuctionId = market.nextAuctionId();
        assertEq(nextAuctionId, 1, "nextAuctionId should remain unchanged");
    }

    function testFailStartAuctionWithoutEnoughBidTickets() public {
        vm.startPrank(user1);
        bidTicket.burn(user1, 1, 100);
        market.startAuction{value: 0.05 ether}(address(mock721), tokenIds, amounts);
    }

    function testFailStartAuctionWithOverlappingTokens() public {
        vm.startPrank(user1);

        market.startAuction{value: 0.05 ether}(address(mock721), tokenIds, amounts);
        market.startAuction{value: 0.05 ether}(address(mock721), tokenIds, amounts);
    }

    //
    // bid()
    //
    function testBid() public {
        vm.startPrank(user1);

        assertEq(bidTicket.balanceOf(user1, 1), 100);
        market.startAuction{value: 0.05 ether}(address(mock721), tokenIds, amounts);
        assertEq(bidTicket.balanceOf(user1, 1), 95);
        market.bid{value: 0.06 ether}(1);
        assertEq(bidTicket.balanceOf(user1, 1), 94);

        (, address highestBidder, uint256 highestBid,,,) = market.auctions(1);

        assertEq(highestBidder, user1, "Highest bidder should be this contract");
        assertEq(highestBid, 0.06 ether, "Highest bid should be 0.06 ether");
    }

    function testBidBelowMinimumIncrement() public {
        vm.startPrank(user1);

        market.startAuction{value: 0.05 ether}(address(mock721), tokenIds, amounts);

        try market.bid{value: 0.055 ether}(1) {
            fail("Should not allow bids below the minimum increment");
        } catch {}

        (,, uint256 highestBid,,,) = market.auctions(1);
        assertEq(highestBid, 0.05 ether, "Highest bid should remain 0.05 ether");
    }

    function testBidRevertOnEqualBid() public {
        vm.startPrank(user1);

        market.startAuction{value: 0.05 ether}(address(mock721), tokenIds, amounts);
        uint32 auctionId = market.nextAuctionId() - 1;

        market.bid{value: 0.06 ether}(auctionId);

        try market.bid{value: 0.06 ether}(auctionId) {
            fail("Should have reverted on equal bid");
        } catch {}
    }

    function testBidAfterAuctionEnded() public {
        vm.startPrank(user1);

        market.startAuction{value: 0.05 ether}(address(mock721), tokenIds, amounts);

        skip(60 * 60 * 24 * 7 + 1);

        try market.bid{value: 0.06 ether}(1) {
            fail("Should not allow bids after the auction has ended");
        } catch {}

        (,, uint256 highestBid,,,) = market.auctions(1);
        assertEq(highestBid, 0.05 ether, "Highest bid should remain 0.05 ether");
    }

    //
    // claim()
    //
    function testClaim() public {
        vm.startPrank(user1);

        uint32 auctionId = market.nextAuctionId();
        market.startAuction{value: 0.05 ether}(address(mock721), tokenIds, amounts);
        assertEq(user1.balance, 0.95 ether, "user1 should have 0.95 after starting the auction");

        vm.startPrank(user2);
        market.bid{value: 0.06 ether}(auctionId);

        (, address highestBidder, uint256 highestBid,,,) = market.auctions(auctionId);

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

    function testClaimBeforeAuctionEnded() public {
        vm.startPrank(user1);

        market.startAuction{value: 0.05 ether}(address(mock721), tokenIds, amounts);

        try market.claim(1) {
            fail("Should not allow claiming before the auction has ended");
        } catch {}

        (, address highestBidder,,,,) = market.auctions(1);
        assertEq(highestBidder, user1, "Highest bidder should remain unchanged");
    }

    function testClaimByNonHighestBidder() public {
        vm.startPrank(user1);

        market.startAuction{value: 0.05 ether}(address(mock721), tokenIds, amounts);

        skip(60 * 60 * 24 * 7 + 1);

        vm.startPrank(user2);

        try market.claim(1) {
            fail("Should not allow non-highest bidders to claim");
        } catch {}

        vm.stopPrank();

        (, address highestBidder,,,,) = market.auctions(1);
        assertEq(highestBidder, user1, "Highest bidder should remain unchanged");
    }

    //
    // withdraw()
    //
    function testWithdrawSuccessful() public {
        vm.startPrank(user1);

        market.startAuction{value: 0.05 ether}(address(mock721), tokenIds, amounts);

        uint32 auctionId = market.nextAuctionId() - 1;
        uint32[] memory auctionIds = new uint32[](1);
        auctionIds[0] = auctionId;

        skip(60 * 60 * 24 * 7 + 1);

        vm.startPrank(address(this));
        market.withdraw(auctionIds);

        (,,,,, bool withdrawn) = market.auctions(auctionId);
        assertTrue(withdrawn, "Auction should be marked as withdrawn");
    }

    function testWithdrawRevertOnActiveAuction() public {
        vm.startPrank(user1);

        market.startAuction{value: 0.05 ether}(address(mock721), tokenIds, amounts);

        uint32 auctionId = market.nextAuctionId() - 1;
        uint32[] memory auctionIds = new uint32[](1);
        auctionIds[0] = auctionId;

        skip(60 * 60 * 24 * 7 + 1);

        vm.startPrank(address(this));
        market.withdraw(auctionIds);

        try market.withdraw(auctionIds) {
            fail("Should have reverted on active auction withdrawal");
        } catch {}
    }

    function testWithdrawRevertOnAlreadyWithdrawnAuction() public {
        vm.startPrank(user1);

        market.startAuction{value: 0.05 ether}(address(mock721), tokenIds, amounts);

        uint32 auctionId = market.nextAuctionId() - 1;
        uint32[] memory auctionIds = new uint32[](1);
        auctionIds[0] = auctionId;

        skip(60 * 60 * 24 * 7 + 1);

        vm.startPrank(address(this));
        market.withdraw(auctionIds);

        try market.withdraw(auctionIds) {
            fail("Should have reverted on already withdrawn auction");
        } catch {}
    }

    //
    // getters/setters
    //
    function testSetMinStartPrice() public {
        market.setMinStartPrice(0.01 ether);

        vm.startPrank(user1);
        market.startAuction{value: 0.01 ether}(address(mock721), tokenIds, amounts);
    }

    function testSetMinBidIncrement() public {
        market.setMinBidIncrement(0.02 ether);

        vm.startPrank(user1);
        market.startAuction{value: 0.05 ether}(address(mock721), tokenIds, amounts);

        market.bid{value: 0.07 ether}(1);

        try market.bid{value: 0.08 ether}(1) {
            fail("Should not allow bids below the minimum increment");
        } catch {}
    }

    function testSetBarnAddress() public {
        market.setBarnAddress(vm.addr(420));
    }

    function testFailSetBarnAddressByNonOwner() public {
        vm.prank(vm.addr(69));
        market.setBarnAddress(vm.addr(420));
    }

    function testSetBidTicketAddress() public {
        market.setBidTicketAddress(vm.addr(420));
    }

    function testFailSetBidTicketAddressByNonOwner() public {
        vm.prank(vm.addr(69));
        market.setBidTicketAddress(vm.addr(420));
    }

    function testSetBidTicketTokenId() public {
        market.setBidTicketTokenId(255);
    }

    function testFailSetBidTicketTokenIdByNonOwner() public {
        vm.prank(vm.addr(69));
        market.setBidTicketTokenId(255);
    }

    function testSetMaxTokens() public {
        market.setMaxTokens(255);
    }
}
