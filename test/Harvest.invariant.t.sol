// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "../src/Harvest.sol";
import "../src/BidTicket.sol";
import "./lib/Mock721.sol";
import "./lib/Mock1155.sol";
import "./lib/Mock20.sol";

contract HarvestInvariantTest is Test {
    Harvest public harvest;
    BidTicket public bidTicket;
    Mock721 public mock721;
    Mock1155 public mock1155;
    Mock20 public mock20;

    address public theBarn;
    address public theFarmer;
    address public user;

    uint256 public constant INITIAL_BALANCE = 100 ether;
    uint256 public constant INITIAL_TOKENS = 1000;

    function setUp() public {
        theBarn = vm.addr(1);
        theFarmer = vm.addr(69);
        user = vm.addr(2);

        bidTicket = new BidTicket(address(this));
        harvest = new Harvest(address(this), theBarn, theFarmer, address(bidTicket));

        bidTicket.setHarvestContract(address(harvest));

        mock721 = new Mock721();
        mock1155 = new Mock1155();
        mock20 = new Mock20();

        mock721.mint(user, INITIAL_TOKENS);
        mock1155.mint(user, 1, INITIAL_TOKENS, "");
        mock20.mint(user, INITIAL_TOKENS);

        vm.startPrank(user);
        mock721.setApprovalForAll(address(harvest), true);
        mock1155.setApprovalForAll(address(harvest), true);
        mock20.approve(address(harvest), type(uint256).max);
        vm.stopPrank();

        vm.deal(address(harvest), INITIAL_BALANCE);
        vm.deal(user, INITIAL_BALANCE);
    }

    function invariant_correctSalePriceAndBidTickets() public view {
        uint256 userInitialBalance = INITIAL_BALANCE;
        uint256 harvestInitialBalance = INITIAL_BALANCE;
        uint256 farmerInitialBalance = INITIAL_BALANCE;

        uint256 userFinalBalance = user.balance;
        uint256 harvestFinalBalance = address(harvest).balance;
        uint256 farmerFinalBalance = theFarmer.balance;
        uint256 actualBidTickets = bidTicket.balanceOf(user, harvest.bidTicketTokenId());

        uint256 salePrice = harvest.salePrice();
        uint256 serviceFee = harvest.serviceFee();
        uint256 bidTicketMultiplier = harvest.bidTicketMultiplier();

        uint256 userBalanceDiff = userFinalBalance > userInitialBalance ? 
            userFinalBalance - userInitialBalance : userInitialBalance - userFinalBalance;
        uint256 harvestBalanceDiff = harvestFinalBalance > harvestInitialBalance ? 
            harvestFinalBalance - harvestInitialBalance : harvestInitialBalance - harvestFinalBalance;
        uint256 farmerBalanceDiff = farmerFinalBalance > farmerInitialBalance ? 
            farmerFinalBalance - farmerInitialBalance : 0;

        uint256 totalTokensSold = salePrice > 0 ? (userBalanceDiff + harvestBalanceDiff) / salePrice : 0;
        uint256 expectedBidTickets = totalTokensSold * bidTicketMultiplier;

        assertLe(
            userBalanceDiff,
            totalTokensSold * salePrice + farmerBalanceDiff,
            "User balance change exceeds expected range"
        );

        assertLe(
            harvestBalanceDiff,
            totalTokensSold * salePrice,
            "Harvest contract balance change exceeds expected range"
        );

        assertLe(
            farmerBalanceDiff,
            totalTokensSold * serviceFee,
            "Farmer balance change exceeds expected range"
        );

        assertEq(
            actualBidTickets,
            expectedBidTickets,
            "User did not receive correct number of bid tickets"
        );

        assertGe(
            farmerBalanceDiff,
            totalTokensSold * serviceFee,
            "Total service fees paid is less than expected"
        );
    }

    function batchSale(uint256 seed) public {
        uint256 tokenCount = (seed % 10) + 1;
        TokenType[] memory types = new TokenType[](tokenCount);
        address[] memory contracts = new address[](tokenCount);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        uint256[] memory counts = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            uint256 tokenType = (seed + i) % 3;
            types[i] = TokenType(tokenType);
            
            if (tokenType == 0) {
                contracts[i] = address(mock20);
                tokenIds[i] = 0;
                counts[i] = ((seed + i) % 100) + 1;
            } else if (tokenType == 1) {
                contracts[i] = address(mock721);
                tokenIds[i] = (seed + i) % INITIAL_TOKENS;
                counts[i] = 1;
            } else {
                contracts[i] = address(mock1155);
                tokenIds[i] = 1;
                counts[i] = ((seed + i) % 5) + 1;
            }
        }

        uint256 totalServiceFee = harvest.serviceFee();
        
        console.log("Total service fee:", totalServiceFee);
        console.log("User balance before:", user.balance);
        
        vm.prank(user);
        harvest.batchSale{value: totalServiceFee}(types, contracts, tokenIds, counts, false);
        
        console.log("User balance after:", user.balance);
    }
}
