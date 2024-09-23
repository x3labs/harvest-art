// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/Harvest.sol";
import "../src/BidTicket.sol";
import "./lib/Mock20.sol";
import "./lib/Mock721.sol";
import "./lib/Mock1155.sol";

contract HarvestTest is Test {
    Harvest public harvest;
    BidTicket public bidTicket;
    Mock721 public mock721;
    Mock1155 public mock1155;
    Mock20 public mock20;

    address public theBarn;
    address public user1;
    address public user2;

    receive() external payable {}
    fallback() external payable {}

    function setUp() public {
        theBarn = vm.addr(1);
        user1 = vm.addr(2);
        user2 = vm.addr(3);

        bidTicket = new BidTicket(address(this));
        harvest = new Harvest(address(this), theBarn, address(bidTicket));

        bidTicket.setHarvestContract(address(harvest));

        mock20 = new Mock20();
        mock20.mint(user1, 1000);
        mock20.mint(user2, 1000);

        mock721 = new Mock721();
        mock721.mint(user1, 200);
        mock721.mint(user2, 200);

        mock1155 = new Mock1155();
        mock1155.mint(user1, 1, 100, "");
        mock1155.mint(user2, 1, 10, "");
        mock1155.mint(user2, 8713622684881697175405882435050837487846425701885818202561849736562519048193, 10, "");

        vm.deal(address(harvest), 10 ether);
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
    }

    function test_batchTransfer_Success_ERC721() public {
        TokenType[] memory tokenTypes = new TokenType[](1);
        address[] memory tokenContracts = new address[](1);
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory counts = new uint256[](1);

        tokenTypes[0] = TokenType.ERC721;
        tokenContracts[0] = address(mock721);
        tokenIds[0] = 1;
        counts[0] = 0;

        harvest.setBarn(theBarn);

        vm.startPrank(user1);
        mock721.setApprovalForAll(address(harvest), true);

        uint256 initialBalance = user1.balance;
        assertEq(bidTicket.balanceOf(user1, 1), 0, "User should not have any bid tickets");

        harvest.batchTransfer(tokenTypes, tokenContracts, tokenIds, counts);

        assertEq(user1.balance, initialBalance + 1 gwei, "User should have gained 1 gwei");
        assertEq(bidTicket.balanceOf(user1, 1), 1, "User should have received 1 bid ticket");
    }

    function test_batchTransfer_Success_MultipleERC721() public {
        TokenType[] memory tokenTypes = new TokenType[](3);
        address[] memory tokenContracts = new address[](3);
        uint256[] memory tokenIds = new uint256[](3);
        uint256[] memory counts = new uint256[](3);

        for (uint256 i; i < 3; i++) {
            tokenTypes[i] = TokenType.ERC721;
            tokenContracts[i] = address(mock721);
            tokenIds[i] = i + 1;
            counts[i] = 0;
        }

        harvest.setBarn(theBarn);

        vm.startPrank(user1);
        mock721.setApprovalForAll(address(harvest), true);

        uint256 initialBalance = user1.balance;
        assertEq(bidTicket.balanceOf(user1, 1), 0, "User should not have any bid tickets");
        harvest.batchTransfer(tokenTypes, tokenContracts, tokenIds, counts);

        assertEq(user1.balance, initialBalance + 3 gwei, "User should have gained 3 gwei");
        assertEq(bidTicket.balanceOf(user1, 1), 3, "User should have received 3 bid tickets");
    }

    function test_batchTransfer_Success_MultipleERC721_WithAddressZero() public {
        uint256 tokenCount = 100;
        TokenType[] memory tokenTypes = new TokenType[](tokenCount);
        address[] memory tokenContracts = new address[](tokenCount);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        uint256[] memory counts = new uint256[](tokenCount);

        for (uint256 i; i < tokenCount; i++) {
            tokenTypes[i] = TokenType.ERC721;
            tokenContracts[i] = i == 0 ? address(mock721) : address(0);
            tokenIds[i] = i + 1;
            counts[i] = 0;
        }

        harvest.setBarn(theBarn);
        harvest.setMaxTokensPerTx(tokenCount);

        vm.startPrank(user1);
        mock721.setApprovalForAll(address(harvest), true);

        uint256 initialBalance = user1.balance;
        assertEq(bidTicket.balanceOf(user1, 1), 0, "User should not have any bid tickets");
        
        harvest.batchTransfer(tokenTypes, tokenContracts, tokenIds, counts);

        assertEq(user1.balance, initialBalance + tokenCount * 1 gwei, "User should have gained 1 gwei");
        assertEq(bidTicket.balanceOf(user1, 1), tokenCount, "User should have received 1 bid ticket");

        for (uint256 i = 1; i <= tokenCount; i++) {
            assertEq(mock721.ownerOf(i), theBarn, "Token should be transferred to theBarn");
        }

        vm.stopPrank();
    }

    function test_batchTransfer_Success_Mixed_ERC721_ERC1155_WithAddressZero() public {
        uint256 tokenCountERC721 = 50;
        uint256 tokenCountERC1155 = 50;
        uint256 tokenCount = tokenCountERC721 + tokenCountERC1155;

        TokenType[] memory tokenTypes = new TokenType[](tokenCount);
        address[] memory tokenContracts = new address[](tokenCount);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        uint256[] memory counts = new uint256[](tokenCount);

        for (uint256 i; i < 50; i++) {
            tokenTypes[i] = TokenType.ERC721;
            tokenContracts[i] = i == 0 ? address(mock721) : address(0);
            tokenIds[i] = i + 1;
            counts[i] = 0;
        }

        // contract does not pay separately per count of ERC1155 token ID
        for (uint256 i = 50; i < tokenCount; i++) {
            tokenTypes[i] = TokenType.ERC1155;
            tokenContracts[i] = i == 50 ? address(mock1155) : address(0);
            tokenIds[i] = 1;
            counts[i] = 1;
        }

        harvest.setBarn(theBarn);
        harvest.setMaxTokensPerTx(tokenCount);

        vm.startPrank(user1);
        mock721.setApprovalForAll(address(harvest), true);
        mock1155.setApprovalForAll(address(harvest), true);

        uint256 initialBalance = user1.balance;
        assertEq(bidTicket.balanceOf(user1, 1), 0, "User should not have any bid tickets");

        harvest.batchTransfer(tokenTypes, tokenContracts, tokenIds, counts);

        assertEq(user1.balance, initialBalance + (tokenCount - tokenCountERC1155 + 1) * 1 gwei, "User should have gained 1 gwei");
        assertEq(bidTicket.balanceOf(user1, 1), (tokenCount - tokenCountERC1155 + 1), "User should have received bid tickets");

        for (uint256 i = 1; i < 50; i++) {
            assertEq(mock721.ownerOf(i), theBarn, "Token should be transferred to theBarn");
        }
        
        assertEq(mock1155.balanceOf(theBarn, 1), 50, "Token should be transferred to theBarn");

        vm.stopPrank();
    }

    function test_batchTransfer_Success_ERC1155() public {
        TokenType[] memory tokenTypes = new TokenType[](1);
        address[] memory tokenContracts = new address[](1);
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory counts = new uint256[](1);

        tokenTypes[0] = TokenType.ERC1155;
        tokenContracts[0] = address(mock1155);
        tokenIds[0] = 1;
        counts[0] = 1;

        harvest.setBarn(theBarn);

        vm.startPrank(user2);
        mock1155.setApprovalForAll(address(harvest), true);

        uint256 initialBalance = user2.balance;
        assertEq(bidTicket.balanceOf(user2, 1), 0, "User should not have any bid tickets");

        harvest.batchTransfer(tokenTypes, tokenContracts, tokenIds, counts);

        assertEq(user2.balance, initialBalance + 1 gwei, "User should have gained 1 gwei");
        assertEq(bidTicket.balanceOf(user2, 1), 1, "User should have received 1 bid ticket");
    }

    function test_batchTransfer_Success_MultipleERC1155() public {
        TokenType[] memory tokenTypes = new TokenType[](3);
        address[] memory tokenContracts = new address[](3);
        uint256[] memory tokenIds = new uint256[](3);
        uint256[] memory counts = new uint256[](3);

        for (uint256 i; i < 3; i++) {
            tokenTypes[i] = TokenType.ERC1155;
            tokenContracts[i] = address(mock1155);
            tokenIds[i] = 1;
            counts[i] = 1;
        }

        harvest.setBarn(theBarn);

        vm.startPrank(user2);
        mock1155.setApprovalForAll(address(harvest), true);

        uint256 initialBalance = user2.balance; 
        assertEq(bidTicket.balanceOf(user2, 1), 0, "User should not have any bid tickets");

        harvest.batchTransfer(tokenTypes, tokenContracts, tokenIds, counts);

        assertEq(user2.balance, initialBalance + 1 gwei, "User should have gained 1 gwei");
        assertEq(bidTicket.balanceOf(user2, 1), 1, "User should have received 1 bid ticket");
    }

    function test_batchTransfer_Success_ERC1155_BigInt() public {
        TokenType[] memory tokenTypes = new TokenType[](1);
        address[] memory tokenContracts = new address[](1);
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory counts = new uint256[](1);

        tokenTypes[0] = TokenType.ERC1155;
        tokenContracts[0] = address(mock1155);
        tokenIds[0] = 8713622684881697175405882435050837487846425701885818202561849736562519048193;
        counts[0] = 1;

        harvest.setBarn(theBarn);

        vm.startPrank(user2);
        mock1155.setApprovalForAll(address(harvest), true);
        harvest.batchTransfer(tokenTypes, tokenContracts, tokenIds, counts);
    }

    function test_batchTransfer_Success_ERC20() public {
        TokenType[] memory tokenTypes = new TokenType[](1);
        address[] memory tokenContracts = new address[](1);
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory counts = new uint256[](1);

        tokenTypes[0] = TokenType.ERC20;
        tokenContracts[0] = address(mock20);
        counts[0] = 1000;
        tokenIds[0] = 0; // Not used for ERC20

        harvest.setBarn(theBarn);

        vm.startPrank(user2);
        mock20.approve(address(harvest), type(uint256).max);
        harvest.batchTransfer(tokenTypes, tokenContracts, tokenIds, counts);

        assertEq(mock20.balanceOf(theBarn), 1000, "User should have received 1000 tokens");
        assertEq(mock20.balanceOf(user2), 0, "user2 should have 900 tokens left");
    }

    function test_batchTransfer_RevertIf_EmptyTokenContracts() public {
        vm.expectRevert(bytes4(keccak256("InvalidTokenContractLength()")));

        TokenType[] memory tokenTypes = new TokenType[](0);
        address[] memory tokenContracts = new address[](0);
        uint256[] memory tokenIds = new uint256[](0);
        uint256[] memory counts = new uint256[](0);

        harvest.batchTransfer(tokenTypes, tokenContracts, tokenIds, counts);
    }

    function test_batchTransfer_RevertIf_MismatchedLengths() public {
        vm.expectRevert(bytes4(keccak256("InvalidParamsLength()")));

        TokenType[] memory tokenTypes = new TokenType[](2);
        address[] memory tokenContracts = new address[](2);
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory counts = new uint256[](1);

        harvest.batchTransfer(tokenTypes, tokenContracts, tokenIds, counts);
    }

    function test_batchTransfer_RevertIf_ExceedMaxTokensPerTx() public {
        harvest.setMaxTokensPerTx(10);

        TokenType[] memory tokenTypes = new TokenType[](11);
        address[] memory tokenContracts = new address[](11);
        uint256[] memory tokenIds = new uint256[](11);
        uint256[] memory counts = new uint256[](11);

        for (uint256 i; i < 11; i++) {
            tokenTypes[i] = TokenType.ERC721;
            tokenContracts[i] = address(mock721);
            tokenIds[i] = i;
            counts[i] = 0;
        }

        vm.startPrank(user1);
        mock721.setApprovalForAll(address(harvest), true);

        vm.expectRevert(bytes4(keccak256("MaxTokensPerTxReached()")));
        harvest.batchTransfer(tokenTypes, tokenContracts, tokenIds, counts);
    }

    function test_withdrawBalance_Success() public {
        harvest.withdrawBalance();
    }

    function test_withdrawBalance_RevertIf_Unauthorized() public {
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        vm.prank(user1);
        harvest.withdrawBalance();
    }

    function test_setSalePrice_Success() public {
        harvest.setSalePrice(100 gwei);
    }

    function test_setBidTicketAddress_Success() public {
        harvest.setBidTicketAddress(address(bidTicket));
    }

    function test_setBidTicketTokenId_Success() public {
        harvest.setBidTicketTokenId(1);
    }

    function test_setBarn_Success() public {
        harvest.setBarn(vm.addr(420));
    }

    function test_setMaxTokensPerTx_Success() public {
        harvest.setMaxTokensPerTx(1000000);
    }
}