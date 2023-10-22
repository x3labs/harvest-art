// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Harvest.sol";
import "../src/BidTicket.sol";
import "./lib/Mock721.sol";
import "./lib/Mock1155.sol";

contract HarvestTest is Test {
    Harvest public harvest;
    BidTicket public bidTicket;
    Mock721 public mock721;
    Mock1155 public mock1155;

    address public theBarn;
    address public user1;
    address public user2;

    receive() external payable {}
    fallback() external payable {}

    function setUp() public {
        bidTicket = new BidTicket();
        harvest = new Harvest(address(bidTicket));
        bidTicket.setHarvestContract(address(harvest));

        mock721 = new Mock721();
        mock1155 = new Mock1155();

        theBarn = vm.addr(1);
        user1 = vm.addr(2);
        user2 = vm.addr(3);

        mock721.mint(user1, 10);
        mock721.mint(user2, 10);

        mock1155.mint(user1, 1, 10, "");
        mock1155.mint(user2, 1, 10, "");

        vm.deal(address(harvest), 10 gwei);
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
    }

    function testFail_BatchTransferNoBarnSet() public {
        address[] memory tokenContracts = new address[](1);
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory counts = new uint256[](1);

        tokenContracts[0] = address(0x1234567890123456789012345678901234567890);
        tokenIds[0] = 1;
        counts[0] = 1;

        harvest.batchTransfer(tokenContracts, tokenIds, counts);
    }

    function testFail_BatchTransferEmptyTokenContracts() public {
        address[] memory tokenContracts = new address[](0);
        uint256[] memory tokenIds = new uint256[](0);
        uint256[] memory counts = new uint256[](0);

        harvest.batchTransfer(tokenContracts, tokenIds, counts);
    }

    function testFail_BatchTransferMismatchedLengths() public {
        address[] memory tokenContracts = new address[](2);
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory counts = new uint256[](1);

        harvest.batchTransfer(tokenContracts, tokenIds, counts);
    }

    function testFail_BatchTransferInvalidTokenCount() public {
        address[] memory tokenContracts = new address[](1);
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory counts = new uint256[](1);
        counts[0] = 0;

        harvest.batchTransfer(tokenContracts, tokenIds, counts);
    }

    function testFail_BatchTransferExceedMaxTokensPerTx() public {
        address[] memory tokenContracts = new address[](101);
        uint256[] memory tokenIds = new uint256[](101);
        uint256[] memory counts = new uint256[](101);

        harvest.batchTransfer(tokenContracts, tokenIds, counts);
    }

    function test_BatchTransferERC721() public {
        address[] memory tokenContracts = new address[](1);
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory counts = new uint256[](1);

        tokenContracts[0] = address(mock721);
        tokenIds[0] = 1;
        counts[0] = 0;

        harvest.setBarn(theBarn);

        vm.startPrank(user1);
        mock721.setApprovalForAll(address(harvest), true);
        harvest.batchTransfer(tokenContracts, tokenIds, counts);
    }

    function test_BatchTransferMultipleERC721() public {
        address[] memory tokenContracts = new address[](3);
        uint256[] memory tokenIds = new uint256[](3);
        uint256[] memory counts = new uint256[](3);

        tokenContracts[0] = address(mock721);
        tokenIds[0] = 1;
        counts[0] = 0;

        tokenContracts[1] = address(mock721);
        tokenIds[1] = 2;
        counts[1] = 0;

        tokenContracts[2] = address(mock721);
        tokenIds[2] = 3;
        counts[2] = 0;

        harvest.setBarn(theBarn);

        vm.startPrank(user1);
        mock721.setApprovalForAll(address(harvest), true);
        harvest.batchTransfer(tokenContracts, tokenIds, counts);
    }

    function test_BatchTransferERC1155() public {
        address[] memory tokenContracts = new address[](1);
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory counts = new uint256[](1);

        tokenContracts[0] = address(mock1155);
        tokenIds[0] = 1;
        counts[0] = 1;

        harvest.setBarn(theBarn);

        vm.startPrank(user2);
        mock1155.setApprovalForAll(address(harvest), true);
        harvest.batchTransfer(tokenContracts, tokenIds, counts);
    }

    function test_BatchTransferMultipleERC1155() public {
        address[] memory tokenContracts = new address[](3);
        uint256[] memory tokenIds = new uint256[](3);
        uint256[] memory counts = new uint256[](3);

        tokenContracts[0] = address(mock1155);
        tokenIds[0] = 1;
        counts[0] = 1;

        tokenContracts[1] = address(mock1155);
        tokenIds[1] = 1;
        counts[1] = 1;

        tokenContracts[2] = address(mock1155);
        tokenIds[2] = 1;
        counts[2] = 1;

        harvest.setBarn(theBarn);

        vm.startPrank(user2);
        mock1155.setApprovalForAll(address(harvest), true);
        harvest.batchTransfer(tokenContracts, tokenIds, counts);
    }

    function test_WithdrawBalance() public {
        harvest.withdrawBalance();
    }

    function testFail_WithdrawBalanceByNonOwner() public {
        vm.prank(user1);
        harvest.withdrawBalance();
    }

    function test_SetPriceByContract() public {
        harvest.setPriceByContract(vm.addr(69), 1 ether);
    }

    function test_SetDefaultPrice() public {
        harvest.setDefaultPrice(1 gwei);
    }

    function test_SetBidTicketAddress() public {
        harvest.setBidTicketAddress(address(bidTicket));
    }

    function test_SetBidTicketTokenId() public {
        harvest.setBidTicketTokenId(1);
    }

    function test_SetBarn() public {
        harvest.setBarn(vm.addr(420));
    }

    function test_SetMaxTokensPerTx() public {
        harvest.setMaxTokensPerTx(1000000);
    }
}
