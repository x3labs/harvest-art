// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/Auctions.sol";
import "../src/BidTicket.sol";
import "./lib/Mock721.sol";
import "./lib/Mock1155.sol";

contract AuctionsInvariantTest is Test {
    Auctions public auctions;
    BidTicket public bidTicket;
    Mock721 public mock721;
    Mock1155 public mock1155;

    address public theBarn;
    address public theFarmer;
    address[] public users;

    function setUp() public {
        theBarn = address(1);
        theFarmer = address(2);

        bidTicket = new BidTicket(address(this));
        auctions = new Auctions(address(this), theBarn, theFarmer, address(bidTicket));
        mock721 = new Mock721();
        mock1155 = new Mock1155();

        bidTicket.setAuctionsContract(address(auctions));

        for (uint256 i = 0; i < 10; i++) {
            address user = address(uint160(i + 100));
            users.push(user);
            vm.deal(user, 100 ether);
            bidTicket.mint(user, 1, 100);
            mock721.mint(user, 5);
            mock1155.mintBatch(user, new uint256[](3), new uint256[](3), "");
        }

        for (uint256 i = 0; i < users.length; i++) {
            vm.prank(users[i]);
            mock721.setApprovalForAll(address(auctions), true);
            mock1155.setApprovalForAll(address(auctions), true);
        }
    }

    function invariant_totalBalanceMatchesUserBalances() public view {
        uint256 totalContractBalance = address(auctions).balance;
        uint256 sumOfUserBalances = 0;
        uint256 sumOfPendingRewards = 0;

        for (uint256 i = 0; i < users.length; i++) {
            sumOfUserBalances += auctions.balances(users[i]);
            
            uint256[] memory auctionIds = new uint256[](auctions.nextAuctionId() - 1);
            for (uint256 j = 1; j < auctions.nextAuctionId(); j++) {
                auctionIds[j - 1] = j;
            }
            sumOfPendingRewards += auctions.getPendingRewards(users[i], auctionIds);
        }

        assertEq(
            totalContractBalance,
            sumOfUserBalances + sumOfPendingRewards,
            "Total contract balance should equal sum of user balances and pending rewards"
        );
    }

    function invariant_auctionStateConsistency() public view {
        for (uint256 i = 1; i < auctions.nextAuctionId(); i++) {
            (,,
                uint64 endTime,
                ,
                Status status,
                address highestBidder,
                uint256 highestBid,
                ,
            ) = auctions.auctions(i);
            
            if (block.timestamp < endTime - 7 days) { // Assuming 7-day auction duration
                assertEq(highestBid, 0, "Auction should not have bids before start");
                assertEq(highestBidder, address(0), "Auction should not have bidder before start");
                assertEq(uint8(status), uint8(Status.Active), "New auction should be active");
            }
            
            if (block.timestamp > endTime && status == Status.Active) {
                assertGt(highestBid, 0, "Ended unsettled auction should have a bid");
                assertNotEq(highestBidder, address(0), "Ended unsettled auction should have a bidder");
            }
            
            if (status == Status.Claimed) {
                assertGt(highestBid, 0, "Claimed auction should have a bid");
                assertNotEq(highestBidder, address(0), "Claimed auction should have a bidder");
            }
        }
    }

    function invariant_nftOwnershipAfterSettlement() public view {
        for (uint256 i = 1; i < auctions.nextAuctionId(); i++) {
            (
                uint8 auctionType,
                address tokenAddress,
                ,,
                Status status,
                address highestBidder,
                ,,
            ) = auctions.auctions(i);

            if (status == Status.Claimed) {
                (uint256[] memory tokenIds, uint256[] memory amounts) = auctions.getAuctionTokens(i);
                
                if (tokenIds.length == 0) {
                    revert("Auction should have at least one token");
                }

                if (auctionType == 0) { // Assuming 0 for ERC721
                    for (uint256 j = 0; j < tokenIds.length; j++) {
                        assertEq(Mock721(tokenAddress).ownerOf(tokenIds[j]), highestBidder, "Highest bidder should own ERC721 after settlement");
                    }
                } else { // ERC1155
                    for (uint256 j = 0; j < tokenIds.length; j++) {
                        assertEq(
                            Mock1155(tokenAddress).balanceOf(highestBidder, tokenIds[j]),
                            amounts[j],
                            "Highest bidder should own correct amount of ERC1155 after settlement"
                        );
                    }
                }
            }
        }
    }

    function createAuction(uint256 userIndex, bool isERC721) public {
        address user = users[userIndex % users.length];
        uint256 startingBid = 0.1 ether + (userIndex * 0.01 ether);
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = userIndex % 5;

        vm.prank(user);
        if (isERC721) {
            auctions.startAuctionERC721{value: startingBid}(startingBid, address(mock721), tokenIds);
        } else {
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = 1;
            auctions.startAuctionERC1155{value: startingBid}(startingBid, address(mock1155), tokenIds, amounts);
        }
    }

    function placeBid(uint256 userIndex, uint256 auctionId) public {
        address user = users[userIndex % users.length];
        uint256 bidAmount = 0.1 ether + (userIndex * 0.01 ether);

        vm.prank(user);
        auctions.bid{value: bidAmount}(auctionId, bidAmount);
    }

    function claim(uint256 userIndex, uint256 auctionId) public {
        address user = users[userIndex % users.length];
        
        vm.prank(user);
        auctions.claim(auctionId);
    }

    function withdraw(uint256 userIndex) public {
        address user = users[userIndex % users.length];
        
        vm.prank(user);
        auctions.withdraw();
    }

}