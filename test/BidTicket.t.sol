// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/BidTicket.sol";

contract MockHarvestContract {
    BidTicket public bidTicket;

    constructor(address _bidTicketAddress) {
        bidTicket = BidTicket(_bidTicketAddress);
    }

    function mockMint(address account, uint256 id, uint256 amount) external {
        bidTicket.mint(account, id, amount);
    }

    function mockMintBatch(address account, uint256[] calldata ids, uint256[] calldata amounts) external {
        bidTicket.mintBatch(account, ids, amounts);
    }
}

contract MockAuctionsContract {
    BidTicket public bidTicket;

    constructor(address _bidTicketAddress) {
        bidTicket = BidTicket(_bidTicketAddress);
    }

    function mockBurn(address account, uint256 id, uint256 amount) external {
        bidTicket.burn(account, id, amount);
    }

    function mockBurnBatch(address account, uint256[] calldata ids, uint256[] calldata amounts) external {
        bidTicket.burnBatch(account, ids, amounts);
    }
}

contract BidTicketTest is Test {
    BidTicket public bidTicket;
    MockHarvestContract public mockHarvest;
    MockAuctionsContract public mockAuctions;
    address public user1;
    address public user2;
    address public user3;
    uint256[] ids = new uint256[](1);
    uint256[] amounts = new uint256[](1);

    function setUp() public {
        bidTicket = new BidTicket(address(this));

        mockHarvest = new MockHarvestContract(address(bidTicket));
        mockAuctions = new MockAuctionsContract(address(bidTicket));

        user1 = vm.addr(1);
        user2 = vm.addr(2);
        user3 = vm.addr(3);

        bidTicket.setHarvestContract(address(mockHarvest));
        bidTicket.setAuctionsContract(address(mockAuctions));

        ids[0] = 1;
        amounts[0] = 100;
    }

    function test_mint_Success_ByOwner() public {
        bidTicket.mint(user1, 1, 100);
        assertEq(bidTicket.balanceOf(user1, 1), 100, "User1 should have 100 BidTickets");
    }

    function test_mint_Success_ByHarvestContract() public {
        vm.startPrank(address(mockHarvest));
        mockHarvest.mockMint(user1, 1, 100);
        assertEq(bidTicket.balanceOf(user1, 1), 100, "User1 should have 100 BidTickets");
    }

    function test_mint_RevertIf_AnyoneElse() public {
        vm.prank(user1);
        try bidTicket.mint(user1, 1, 100) {
            fail();
        } catch {}
    }

    function test_mintBatch_Success_ByOwner() public {
        bidTicket.mintBatch(user1, ids, amounts);
        assertEq(bidTicket.balanceOf(user1, 1), 100, "User1 should have 100 BidTickets");
    }

    function test_mintBatch_Success_ByHarvestContract() public {
        vm.startPrank(address(mockHarvest));
        mockHarvest.mockMintBatch(user1, ids, amounts);
        assertEq(bidTicket.balanceOf(user1, 1), 100, "User1 should have 100 BidTickets");
    }

    function test_mintBatch_RevertIf_AnyoneElse() public {
        vm.prank(user1);
        try bidTicket.mintBatch(user1, ids, amounts) {
            fail();
        } catch {}
    }

    function test_burn_Success_ByOwner() public {
        bidTicket.mint(user1, 1, 100);
        bidTicket.burn(user1, 1, 50);
        assertEq(bidTicket.balanceOf(user1, 1), 50, "User1 should have 50 BidTickets after burning");
    }

    function test_burn_Success_ByAuctionsContract() public {
        bidTicket.mint(user1, 1, 100);
        mockAuctions.mockBurn(user1, 1, 50);
        assertEq(bidTicket.balanceOf(user1, 1), 50, "User1 should have 50 BidTickets after burning");
    }

    function test_burn_RevertIf_AnyoneElse() public {
        bidTicket.mint(user1, 1, 100);
        vm.startPrank(user1);
        try bidTicket.burn(user1, 1, 50) {
            fail();
        } catch {}
    }

    function test_burnBatch_Success_ByOwner() public {
        bidTicket.mintBatch(user1, ids, amounts);
        bidTicket.burnBatch(user1, ids, amounts);
        assertEq(bidTicket.balanceOf(user1, 1), 0, "User1 should have 0 BidTickets after burning");
    }

    function test_burnBatch_Success_ByAuctionsContract() public {
        bidTicket.mintBatch(user1, ids, amounts);
        mockAuctions.mockBurnBatch(user1, ids, amounts);
        assertEq(bidTicket.balanceOf(user1, 1), 0, "User1 should have 0 BidTickets after burning");
    }

    function test_burnBatch_RevertIf_AnyoneElse() public {
        bidTicket.mintBatch(user1, ids, amounts);
        vm.startPrank(user1);
        try bidTicket.burnBatch(user1, ids, amounts) {
            fail();
        } catch {}
    }

    function test_setURI_Success() public {
        string memory newURI = "https://newuri.example.com/api/token/{id}.json";
        bidTicket.setURI(1, newURI);
        assertEq(bidTicket.uri(1), newURI, "Token URI should be updated");
    }

    function test_setURI_RevertIf_NotOwner() public {
        vm.startPrank(user1);
        try bidTicket.setURI(1, "https://newuri.example.com/api/token/{id}.json") {
            fail();
        } catch {}
    }

    function test_setHarvestContract_Success() public {
        bidTicket.setHarvestContract(address(mockHarvest));
        assertEq(bidTicket.harvestContract(), address(mockHarvest), "Harvest contract should be updated");
    }

    function test_setAuctionsContract_Success() public {
        bidTicket.setAuctionsContract(address(mockAuctions));
        assertEq(bidTicket.auctionsContract(), address(mockAuctions), "Auctions contract should be updated");
    }
}
