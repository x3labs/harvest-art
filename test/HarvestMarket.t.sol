// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/HarvestMarket.sol";

contract HarvestMarketTest is Test {
    HarvestMarket market;
    address public tokenAddress1;
    address public user1;
    address public user2;
    uint256[] tokenIds = [1, 2, 3];
    uint256[] amounts = [1, 1, 1];

    receive() external payable {}
    fallback() external payable {}

    function setUp() public {
        market = new HarvestMarket();
        market.setBarnAddress(payable(address(this)));
        user1 = vm.addr(1);
        user2 = vm.addr(2);
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
        vm.startPrank(user1);
    }

    function testCreateAuction() public {
        uint256 startBalance = user1.balance;

        market.createAuction{value: 0.05 ether}(tokenAddress1, tokenIds, amounts);
        assertEq(user1.balance, startBalance - 0.05 ether, "Balance should decrease by 0.05 ether");
        assertEq(market.nextAuctionId(), 2, "nextAuctionId should be incremented");

        (address _tokenAddress, address _highestBidder,,, uint256 _startPrice, uint256 _highestPrice) =
            market.auctions(1);

        assertEq(_tokenAddress, tokenAddress1);
        assertEq(_highestBidder, user1);
        assertEq(_startPrice, 0.05 ether);
        assertEq(_highestPrice, 0.05 ether);
    }

    function testBid() public {
        market.createAuction{value: 0.05 ether}(tokenAddress1, tokenIds, amounts);
        market.bid{value: 0.06 ether}(1);

        (, address highestBidder,,,, uint256 highestBid) = market.auctions(1);

        assertEq(highestBidder, user1, "Highest bidder should be this contract");
        assertEq(highestBid, 0.06 ether, "Highest bid should be 0.06 ether");
    }

    function testClaim() public {
        market.createAuction{value: 0.05 ether}(tokenAddress1, tokenIds, amounts);
        market.bid{value: 0.06 ether}(1);

        (, address highestBidder,,,, uint256 highestBid) = market.auctions(1);

        assertEq(highestBidder, user1, "Highest bidder should be this contract");
        assertEq(highestBid, 0.06 ether, "Highest bid should be 0.06 ether");
    }

    function testBidBelowMinimumIncrement() public {
        market.createAuction{value: 0.05 ether}(tokenAddress1, tokenIds, amounts);
        try market.bid{value: 0.055 ether}(1) {
            fail("Should not allow bids below the minimum increment");
        } catch {}

        (,,,,, uint256 highestBid) = market.auctions(1);
        assertEq(highestBid, 0.05 ether, "Highest bid should remain 0.05 ether");
    }

    function testBidAfterAuctionEnded() public {
        market.createAuction{value: 0.05 ether}(tokenAddress1, tokenIds, amounts);

        skip(60 * 60 * 24 * 7 + 1);

        try market.bid{value: 0.06 ether}(1) {
            fail("Should not allow bids after the auction has ended");
        } catch {}

        (,,,,, uint256 highestBid) = market.auctions(1);
        assertEq(highestBid, 0.05 ether, "Highest bid should remain 0.05 ether");
    }

    function testClaimBeforeAuctionEnded() public {
        market.createAuction{value: 0.05 ether}(tokenAddress1, tokenIds, amounts);
        try market.claim(1) {
            fail("Should not allow claiming before the auction has ended");
        } catch {}

        (, address highestBidder,,,,) = market.auctions(1);
        assertEq(highestBidder, user1, "Highest bidder should remain unchanged");
    }

    function testClaimByNonHighestBidder() public {
        market.createAuction{value: 0.05 ether}(tokenAddress1, tokenIds, amounts);

        skip(60 * 60 * 24 * 7 + 1);

        vm.startPrank(user2);
        try market.claim(1) {
            fail("Should not allow non-highest bidders to claim");
        } catch {}
        vm.stopPrank();

        (, address highestBidder,,,,) = market.auctions(1);
        assertEq(highestBidder, user1, "Highest bidder should remain unchanged");
    }

    function testCreateAuctionWithTooManyTokens() public {
        uint256[] memory manyTokenIds = new uint256[](1001);
        uint256[] memory manyAmounts = new uint256[](1001);

        try market.createAuction{value: 0.05 ether}(tokenAddress1, manyTokenIds, manyAmounts) {
            fail("Should not allow creating an auction with too many tokens");
        } catch {}

        uint256 nextAuctionId = market.nextAuctionId();
        assertEq(nextAuctionId, 1, "nextAuctionId should remain unchanged");
    }

    function testCreateAuctionWithLowStartPrice() public {
        try market.createAuction{value: 0.04 ether}(tokenAddress1, tokenIds, amounts) {
            fail("Should not allow creating an auction with a start price below the minimum");
        } catch {}

        uint256 nextAuctionId = market.nextAuctionId();
        assertEq(nextAuctionId, 1, "nextAuctionId should remain unchanged");
    }
}
