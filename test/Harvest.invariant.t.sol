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
        harvest = new Harvest(address(this), theBarn, theFarmer,address(bidTicket));

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
        uint256 totalTokensTransferred;
        uint256 expectedBidTickets;

        uint256 userFinalBalance = user.balance;
        uint256 harvestFinalBalance = address(harvest).balance;
        uint256 actualBidTickets = bidTicket.balanceOf(user, harvest.bidTicketTokenId());

        uint256 salePrice = harvest.salePrice();
        uint256 bidTicketMultiplier = harvest.bidTicketMultiplier();

        if (userFinalBalance > userInitialBalance) {
            totalTokensTransferred = (userFinalBalance - userInitialBalance) / salePrice;
        } else {
            totalTokensTransferred = (harvestInitialBalance - harvestFinalBalance) / salePrice;
        }

        expectedBidTickets = totalTokensTransferred * bidTicketMultiplier;

        assertEq(
            userFinalBalance,
            userInitialBalance + (totalTokensTransferred * salePrice),
            "User did not receive correct amount of ETH"
        );

        assertEq(
            harvestFinalBalance,
            harvestInitialBalance - (totalTokensTransferred * salePrice),
            "Harvest contract balance did not decrease correctly"
        );

        assertEq(
            actualBidTickets,
            expectedBidTickets,
            "User did not receive correct number of bid tickets"
        );

        uint256 totalErc721Sold = INITIAL_TOKENS - mock721.balanceOf(user);
        uint256 totalErc1155Sold = INITIAL_TOKENS - mock1155.balanceOf(user, 1);
        uint256 totalErc20Sold = INITIAL_TOKENS - mock20.balanceOf(user);

        uint256 totalTokensSold = totalErc721Sold + totalErc1155Sold + totalErc20Sold;

        assertEq(
            totalTokensSold,
            totalTokensTransferred,
            "Total tokens sold does not match ETH transferred"
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
                contracts[i] = address(mock721);
                tokenIds[i] = (seed + i) % INITIAL_TOKENS;
                counts[i] = 1;
            } else if (tokenType == 1) {
                contracts[i] = address(mock1155);
                tokenIds[i] = 1;
                counts[i] = ((seed + i) % 5) + 1;
            } else {
                contracts[i] = address(mock20);
                tokenIds[i] = 0;
                counts[i] = ((seed + i) % 100) + 1;
            }
        }

        vm.prank(user);
        harvest.batchSale(types, contracts, tokenIds, counts, false);
    }

    function erc721SingleSale(uint256 seed) public {
        uint256 tokenId = seed % INITIAL_TOKENS;
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;

        vm.prank(user);
        harvest.erc721Sale(address(mock721), tokenIds, false);
    }

    function erc1155SingleSale(uint256 seed) public {
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        tokenIds[0] = 1;
        amounts[0] = (seed % 5) + 1;

        vm.prank(user);
        harvest.erc1155Sale(address(mock1155), tokenIds, amounts, false);
    }

    function erc20SingleSale(uint256 seed) public {
        uint256 amount = (seed % 100) + 1;
        
        vm.prank(user);
        harvest.erc20Sale(address(mock20), amount, false);
    }
}
