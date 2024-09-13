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
    MockERC20 public mockERC20;

    address public theBarn;
    address public user;

    uint256 public constant INITIAL_BALANCE = 100 ether;
    uint256 public constant INITIAL_TOKENS = 1000;

    function setUp() public {
        theBarn = vm.addr(1);
        user = vm.addr(2);

        bidTicket = new BidTicket(address(this));
        harvest = new Harvest(address(this), theBarn, address(bidTicket));

        bidTicket.setHarvestContract(address(harvest));

        mock721 = new Mock721();
        mock1155 = new Mock1155();
        mockERC20 = new MockERC20();

        // Mint tokens to user
        mock721.mint(user, INITIAL_TOKENS);
        mock1155.mint(user, 1, INITIAL_TOKENS, "");
        mockERC20.mint(user, INITIAL_TOKENS);

        // Set up approvals
        vm.startPrank(user);
        mock721.setApprovalForAll(address(harvest), true);
        mock1155.setApprovalForAll(address(harvest), true);
        mockERC20.approve(address(harvest), type(uint256).max);
        vm.stopPrank();

        // Fund contracts
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

        // Calculate total tokens transferred based on balance changes
        if (userFinalBalance > userInitialBalance) {
            totalTokensTransferred = (userFinalBalance - userInitialBalance) / salePrice;
        } else {
            totalTokensTransferred = (harvestInitialBalance - harvestFinalBalance) / salePrice;
        }

        expectedBidTickets = totalTokensTransferred * bidTicketMultiplier;

        // Check if the user received the correct amount of ETH
        assertEq(
            userFinalBalance,
            userInitialBalance + (totalTokensTransferred * salePrice),
            "User did not receive correct amount of ETH"
        );

        // Check if the Harvest contract's balance decreased correctly
        assertEq(
            harvestFinalBalance,
            harvestInitialBalance - (totalTokensTransferred * salePrice),
            "Harvest contract balance did not decrease correctly"
        );

        // Check if the user received the correct number of bid tickets
        assertEq(
            actualBidTickets,
            expectedBidTickets,
            "User did not receive correct number of bid tickets"
        );
    }

    function invariant_tokenBalancesNeverExceedInitial() public view {
        assertLe(mock721.balanceOf(user), INITIAL_TOKENS, "ERC721 balance exceeded initial amount");
        assertLe(mock1155.balanceOf(user, 1), INITIAL_TOKENS, "ERC1155 balance exceeded initial amount");
        assertLe(mockERC20.balanceOf(user), INITIAL_TOKENS, "ERC20 balance exceeded initial amount");
    }

    // Helper function to perform random batch transfers
    function batchTransfer(uint256 seed) public {
        uint256 tokenCount = (seed % 10) + 1; // 1 to 10 tokens per transfer
        TokenType[] memory types = new TokenType[](tokenCount);
        address[] memory contracts = new address[](tokenCount);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        uint256[] memory counts = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            uint256 tokenType = (seed + i) % 3;
            types[i] = TokenType(tokenType);
            
            if (tokenType == 0) { // ERC721
                contracts[i] = address(mock721);
                tokenIds[i] = (seed + i) % INITIAL_TOKENS;
                counts[i] = 1;
            } else if (tokenType == 1) { // ERC1155
                contracts[i] = address(mock1155);
                tokenIds[i] = 1;
                counts[i] = ((seed + i) % 5) + 1; // 1 to 5 tokens
            } else { // ERC20
                contracts[i] = address(mockERC20);
                tokenIds[i] = 0;
                counts[i] = ((seed + i) % 100) + 1; // 1 to 100 tokens
            }
        }

        vm.prank(user);
        harvest.batchTransfer(types, contracts, tokenIds, counts);
    }
}
