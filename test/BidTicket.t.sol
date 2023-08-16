// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/BidTicket.sol";

contract MockHarvestContract {
    BidTicket public bidTicket;

    constructor(address _bidTicketAddress) {
        bidTicket = BidTicket(_bidTicketAddress);
    }

    function mockMint(address account, uint256 id, uint256 amount, bytes memory data) external {
        bidTicket.mint(account, id, amount, data);
    }
}

contract MockMarketContract {
    BidTicket public bidTicket;

    constructor(address _bidTicketAddress) {
        bidTicket = BidTicket(_bidTicketAddress);
    }

    function mockBurn(address account, uint256 id, uint256 amount) external {
        bidTicket.burn(account, id, amount);
    }
}

contract BidTicketTest is Test {
    BidTicket public bidTicket;
    MockHarvestContract public mockHarvest;
    MockMarketContract public mockMarket;
    address public user1;
    address public user2;
    address public user3;

    function setUp() public {
        bidTicket = new BidTicket();

        mockHarvest = new MockHarvestContract(address(bidTicket));
        mockMarket = new MockMarketContract(address(bidTicket));

        user1 = vm.addr(1);
        user2 = vm.addr(2);
        user3 = vm.addr(3);

        bidTicket.setHarvestContract(address(mockHarvest));
        bidTicket.setMarketContract(address(mockMarket));
    }

    function testMintByOwner() public {
        bidTicket.mint(user1, 1, 100, "");
        assertEq(bidTicket.balanceOf(user1, 1), 100, "User1 should have 100 BidTickets");
    }

    function testMintByHarvestContract() public {
        vm.startPrank(address(mockHarvest));
        mockHarvest.mockMint(user1, 1, 100, "");
        assertEq(bidTicket.balanceOf(user1, 1), 100, "User1 should have 100 BidTickets");
    }

    function testFailMintByOther() public {
        vm.prank(user1);
        bidTicket.mint(user1, 1, 100, "");
    }

    function testBurnByOwner() public {
        bidTicket.mint(user1, 1, 100, "");
        bidTicket.burn(user1, 1, 50);
        assertEq(bidTicket.balanceOf(user1, 1), 50, "User1 should have 50 BidTickets after burning");
    }

    function testBurnByMarketContract() public {
        bidTicket.mint(user1, 1, 100, "");
        mockMarket.mockBurn(user1, 1, 50);
        assertEq(bidTicket.balanceOf(user1, 1), 50, "User1 should have 50 BidTickets after burning");
    }

    function testFailBurnByOther() public {
        bidTicket.mint(user1, 1, 100, "");
        vm.startPrank(user1);
        bidTicket.burn(user1, 1, 50);
    }

    function testSetURI() public {
        string memory newURI = "https://newuri.example.com/api/token/{id}.json";
        bidTicket.setURI(1, newURI);
        assertEq(bidTicket.uri(1), newURI, "Token URI should be updated");
    }
}
