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
    address public theFarmer;
    address public user1;
    address public user2;

    receive() external payable {}
    fallback() external payable {}

    function setUp() public {
        theBarn = vm.addr(1);
        theFarmer = vm.addr(69);
        user1 = vm.addr(2);
        user2 = vm.addr(3);

        bidTicket = new BidTicket(address(this));
        harvest = new Harvest(address(this), theBarn, theFarmer, address(bidTicket));

        bidTicket.setHarvestContract(address(harvest));

        harvest.setServiceFee(0 ether);

        mock20 = new Mock20();
        mock20.mint(user1, 1000);
        mock20.mint(user2, 1000);

        mock721 = new Mock721();
        mock721.mint(user1, 1000);
        mock721.mint(user2, 1000);

        mock1155 = new Mock1155();
        mock1155.mint(user1, 1, 1000, "");
        mock1155.mint(user1, 2, 1000, "");
        mock1155.mint(user2, 1, 100, "");
        mock1155.mint(user2, 2, 100, "");
        mock1155.mint(user2, 8713622684881697175405882435050837487846425701885818202561849736562519048193, 10, "");

        vm.deal(address(harvest), 10 ether);
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);
    }

    function test_batchSale_Success_ERC721() public {
        TokenType[] memory tokenTypes = new TokenType[](1);
        address[] memory tokenContracts = new address[](1);
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory counts = new uint256[](1);

        tokenTypes[0] = TokenType.ERC721;
        tokenContracts[0] = address(mock721);
        tokenIds[0] = 1;
        counts[0] = 0;

        harvest.setBarn(theBarn);
        harvest.setServiceFee(0.01 ether);

        vm.startPrank(user1);
        mock721.setApprovalForAll(address(harvest), true);

        uint256 initialBalance = user1.balance;
        assertEq(bidTicket.balanceOf(user1, 1), 0, "User should not have any bid tickets");

        harvest.batchSale{value: 0.01 ether}(tokenTypes, tokenContracts, tokenIds, counts, false);

        assertEq(user1.balance, initialBalance + 1 gwei - harvest.serviceFee(), "User should have gained 1 gwei minus service fee");
        assertEq(bidTicket.balanceOf(user1, 1), 1, "User should have received 1 bid ticket");
        assertEq(address(theFarmer).balance, 0.01 ether - 1 gwei, "Farmer should have received the service fee");
    }

    function test_batchSale_Success_MultipleERC721() public {
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
        harvest.batchSale(tokenTypes, tokenContracts, tokenIds, counts, false);

        assertEq(user1.balance, initialBalance + 3 gwei, "User should have gained 3 gwei");
        assertEq(bidTicket.balanceOf(user1, 1), 3, "User should have received 3 bid tickets");
    }

    function test_batchSale_Success_MultipleERC721_WithAddressZero() public {
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
        
        harvest.batchSale(tokenTypes, tokenContracts, tokenIds, counts, false);

        assertEq(user1.balance, initialBalance + tokenCount * 1 gwei, "User should have gained 1 gwei");
        assertEq(bidTicket.balanceOf(user1, 1), tokenCount, "User should have received 1 bid ticket");

        for (uint256 i = 1; i <= tokenCount; i++) {
            assertEq(mock721.ownerOf(i), theBarn, "Token should be transferred to theBarn");
        }

        vm.stopPrank();
    }

    function test_batchSale_Success_Mixed_ERC721_ERC1155_WithAddressZero() public {
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

        for (uint256 i = 50; i < tokenCount; i++) {
            tokenTypes[i] = TokenType.ERC1155;
            tokenContracts[i] = i == 50 ? address(mock1155) : address(0);
            tokenIds[i] = 1;
            counts[i] = 1;
        }

        harvest.setBarn(theBarn);
        harvest.setMaxTokensPerTx(tokenCount);
        harvest.setServiceFee(0.01 ether);

        vm.startPrank(user1);
        mock721.setApprovalForAll(address(harvest), true);
        mock1155.setApprovalForAll(address(harvest), true);

        uint256 initialBalance = user1.balance;
        assertEq(bidTicket.balanceOf(user1, 1), 0, "User should not have any bid tickets");

        harvest.batchSale{value: 0.01 ether}(tokenTypes, tokenContracts, tokenIds, counts, false);

        assertEq(user1.balance, initialBalance + tokenCount * 1 gwei - harvest.serviceFee(), "User should have gained 1 gwei minus service fee");
        assertEq(bidTicket.balanceOf(user1, 1), tokenCount, "User should have received bid tickets");

        for (uint256 i = 1; i < 50; i++) {
            assertEq(mock721.ownerOf(i), theBarn, "Token should be transferred to theBarn");
        }
        
        assertEq(mock1155.balanceOf(theBarn, 1), 50, "Token should be transferred to theBarn");
        assertEq(address(theFarmer).balance, 0.01 ether - tokenCount * 1 gwei, "Farmer should have received the service fee");

        vm.stopPrank();
    }

    function test_batchSale_Success_ERC1155() public {
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

        harvest.batchSale(tokenTypes, tokenContracts, tokenIds, counts, false);

        assertEq(user2.balance, initialBalance + 1 gwei, "User should have gained 1 gwei");
        assertEq(bidTicket.balanceOf(user2, 1), 1, "User should have received 1 bid ticket");
    }

    function test_batchSale_Success_MultipleERC1155() public {
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

        harvest.batchSale(tokenTypes, tokenContracts, tokenIds, counts, false);

        assertEq(user2.balance, initialBalance + 3 gwei, "User should have gained 3 gwei");
        assertEq(bidTicket.balanceOf(user2, 1), 3, "User should have received 3 bid ticket");
    }

    function test_batchSale_Success_ERC1155_BigInt() public {
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
        harvest.batchSale(tokenTypes, tokenContracts, tokenIds, counts, false);
    }

    function test_batchSale_Success_ERC20() public {
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
        harvest.batchSale(tokenTypes, tokenContracts, tokenIds, counts, false);

        assertEq(mock20.balanceOf(theBarn), 1000, "User should have received 1000 tokens");
        assertEq(mock20.balanceOf(user2), 0, "user2 should have 900 tokens left");
    }

    function test_batchSale_RevertIf_EmptyTokenContracts() public {
        vm.expectRevert(bytes4(keccak256("InvalidParamsLength()")));

        TokenType[] memory tokenTypes = new TokenType[](0);
        address[] memory tokenContracts = new address[](0);
        uint256[] memory tokenIds = new uint256[](0);
        uint256[] memory counts = new uint256[](0);

        harvest.batchSale(tokenTypes, tokenContracts, tokenIds, counts, false);
    }

    function test_batchSale_RevertIf_MismatchedLengths() public {
        vm.expectRevert(bytes4(keccak256("InvalidParamsLength()")));

        TokenType[] memory tokenTypes = new TokenType[](2);
        address[] memory tokenContracts = new address[](2);
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory counts = new uint256[](1);

        harvest.batchSale(tokenTypes, tokenContracts, tokenIds, counts, false);
    }

    function test_batchSale_RevertIf_ExceedMaxTokensPerTx() public {
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
        harvest.batchSale(tokenTypes, tokenContracts, tokenIds, counts, false);
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

    function test_erc20Sale_Success() public {
        uint256 amount = 500;
        harvest.setBarn(theBarn);

        vm.startPrank(user1);
        mock20.approve(address(harvest), type(uint256).max);

        uint256 initialBalance = user1.balance;
        assertEq(bidTicket.balanceOf(user1, 1), 0, "User should not have any bid tickets");

        harvest.erc20Sale(address(mock20), amount, false);

        assertEq(user1.balance, initialBalance + 1 gwei, "User should have gained 1 gwei");
        assertEq(bidTicket.balanceOf(user1, 1), 1, "User should have received 1 bid ticket");
        assertEq(mock20.balanceOf(theBarn), amount, "Barn should have received the tokens");
        assertEq(mock20.balanceOf(user1), 1000 - amount, "User should have transferred the tokens");

        vm.stopPrank();
    }

    function test_erc20Sale_Success_WithServiceFee() public {
        uint256 amount = 500;
        harvest.setBarn(theBarn);
        harvest.setServiceFee(0.01 ether);

        vm.startPrank(user1);
        mock20.approve(address(harvest), type(uint256).max);

        uint256 initialBalance = user1.balance;
        assertEq(bidTicket.balanceOf(user1, 1), 0, "User should not have any bid tickets");

        harvest.erc20Sale{value: 0.01 ether}(address(mock20), amount, false);

        assertEq(user1.balance, initialBalance + 1 gwei - harvest.serviceFee(), "User should have gained 1 gwei minus service fee");
        assertEq(bidTicket.balanceOf(user1, 1), 1, "User should have received 1 bid ticket");
        assertEq(mock20.balanceOf(theBarn), amount, "Barn should have received the tokens");
        assertEq(mock20.balanceOf(user1), 1000 - amount, "User should have transferred the tokens");
        assertEq(address(theFarmer).balance, 0.01 ether - 1 gwei, "Farmer should have received the service fee");

        vm.stopPrank();
    }


    function test_erc721Sale_Success() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;

        harvest.setBarn(theBarn);

        vm.startPrank(user1);
        mock721.setApprovalForAll(address(harvest), true);

        uint256 initialBalance = user1.balance;
        assertEq(bidTicket.balanceOf(user1, 1), 0, "User should not have any bid tickets");

        harvest.erc721Sale(address(mock721), tokenIds, false);

        assertEq(user1.balance, initialBalance + 3 gwei, "User should have gained 3 gwei");
        assertEq(bidTicket.balanceOf(user1, 1), 3, "User should have received 3 bid tickets");
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(mock721.ownerOf(tokenIds[i]), theBarn, "Token should be transferred to theBarn");
        }

        vm.stopPrank();
    }

    function test_erc721Sale_Success_WithServiceFee() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;

        harvest.setBarn(theBarn);
        harvest.setServiceFee(0.01 ether);

        vm.startPrank(user1);
        mock721.setApprovalForAll(address(harvest), true);

        uint256 initialBalance = user1.balance;
        assertEq(bidTicket.balanceOf(user1, 1), 0, "User should not have any bid tickets");

        harvest.erc721Sale{value: 0.01 ether}(address(mock721), tokenIds, false);

        assertEq(user1.balance, initialBalance + 3 gwei - harvest.serviceFee(), "User should have gained 3 gwei minus service fee");
        assertEq(bidTicket.balanceOf(user1, 1), 3, "User should have received 3 bid tickets");
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(mock721.ownerOf(tokenIds[i]), theBarn, "Token should be transferred to theBarn");
        }

        assertEq(address(theFarmer).balance, 0.01 ether - 3 gwei, "Farmer should have received the service fee");

        vm.stopPrank();
    }

    function test_erc1155Sale_Success() public {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        uint256[] memory counts = new uint256[](2);
        counts[0] = 5;
        counts[1] = 3;

        harvest.setBarn(theBarn);

        vm.startPrank(user1);
        mock1155.setApprovalForAll(address(harvest), true);

        uint256 initialBalance = user1.balance;
        assertEq(bidTicket.balanceOf(user1, 1), 0, "User should not have any bid tickets");

        harvest.erc1155Sale(address(mock1155), tokenIds, counts, false);

        assertEq(user1.balance, initialBalance + 2 gwei, "User should have gained 2 gwei");
        assertEq(bidTicket.balanceOf(user1, 1), 2, "User should have received 2 bid tickets");
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(mock1155.balanceOf(theBarn, tokenIds[i]), counts[i], "Tokens should be transferred to theBarn");
        }

        vm.stopPrank();
    }

    function test_erc1155Sale_Success_WithServiceFee() public {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;

        uint256[] memory counts = new uint256[](2);
        counts[0] = 5;
        counts[1] = 3;

        harvest.setBarn(theBarn);
        harvest.setServiceFee(0.01 ether);

        vm.startPrank(user1);
        mock1155.setApprovalForAll(address(harvest), true);

        uint256 initialBalance = user1.balance;
        assertEq(bidTicket.balanceOf(user1, 1), 0, "User should not have any bid tickets");

        harvest.erc1155Sale{value: 0.01 ether}(address(mock1155), tokenIds, counts, false);

        assertEq(user1.balance, initialBalance + 2 gwei - harvest.serviceFee(), "User should have gained 2 gwei minus service fee");
        assertEq(bidTicket.balanceOf(user1, 1), 2, "User should have received 2 bid tickets");
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(mock1155.balanceOf(theBarn, tokenIds[i]), counts[i], "Tokens should be transferred to theBarn");
        }

        assertEq(address(theFarmer).balance, 0.01 ether - 2 gwei, "Farmer should have received the service fee");

        vm.stopPrank();
    }

    function test_erc20Sale_RevertIf_InsufficientBalance() public {
        uint256 amount = 1001;
        harvest.setBarn(theBarn);

        vm.startPrank(user1);
        mock20.approve(address(harvest), type(uint256).max);

        vm.expectPartialRevert(bytes4(keccak256("ERC20InsufficientBalance(address,uint256,uint256)")));
        harvest.erc20Sale(address(mock20), amount, false);

        vm.stopPrank();
    }

    function test_erc721Sale_RevertIf_NotOwner() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1001;

        harvest.setBarn(theBarn);

        vm.startPrank(user1);
        mock721.setApprovalForAll(address(harvest), true);

        vm.expectPartialRevert(bytes4(keccak256("ERC721InsufficientApproval(address,uint256)")));
        harvest.erc721Sale(address(mock721), tokenIds, false);

        vm.stopPrank();
    }

    function test_erc1155Sale_RevertIf_InsufficientBalance() public {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;

        uint256[] memory counts = new uint256[](1);
        counts[0] = 1001;

        harvest.setBarn(theBarn);

        vm.startPrank(user1);
        mock1155.setApprovalForAll(address(harvest), true);

        vm.expectPartialRevert(bytes4(keccak256("ERC1155InsufficientBalance(address,uint256,uint256,uint256)")));
        harvest.erc1155Sale(address(mock1155), tokenIds, counts, false);

        vm.stopPrank();
    }

    function testGas_erc721Sale() public {
        uint256[] memory tokenIds = new uint256[](100);
        for (uint256 i = 0; i < 100; i++) {
            tokenIds[i] = i + 1;
        }

        harvest.setBarn(theBarn);

        vm.startPrank(user1);
        mock721.setApprovalForAll(address(harvest), true);

        uint256 gasStart = gasleft();
        harvest.erc721Sale(address(mock721), tokenIds, false);
        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used by erc721Sale:", gasUsed);

        vm.stopPrank();
    }

    function testGas_batchSale_ERC721() public {
        uint256 tokenCount = 100;
        TokenType[] memory tokenTypes = new TokenType[](tokenCount);
        address[] memory tokenContracts = new address[](tokenCount);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        uint256[] memory counts = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            tokenTypes[i] = TokenType.ERC721;
            tokenContracts[i] = address(mock721);
            tokenIds[i] = i + 1;
            counts[i] = 0;
        }

        harvest.setBarn(theBarn);

        vm.startPrank(user1);
        mock721.setApprovalForAll(address(harvest), true);

        uint256 gasStart = gasleft();
        harvest.batchSale(tokenTypes, tokenContracts, tokenIds, counts, false);
        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used by batchSale for ERC721:", gasUsed);

        vm.stopPrank();
    }

    function testGas_batchSale_ERC721_Zeros() public {
        uint256 tokenCount = 100;
        TokenType[] memory tokenTypes = new TokenType[](tokenCount);
        address[] memory tokenContracts = new address[](tokenCount);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        uint256[] memory counts = new uint256[](tokenCount);

        tokenTypes[0] = TokenType.ERC721;
        tokenContracts[0] = address(mock721);
        tokenIds[0] = 1;
        counts[0] = 0;
        
        for (uint256 i = 1; i < tokenCount; i++) {
            tokenTypes[i] = TokenType.ERC721;
            tokenContracts[i] = address(0);
            tokenIds[i] = i + 1;
            counts[i] = 0;
        }

        harvest.setBarn(theBarn);

        vm.startPrank(user1);
        mock721.setApprovalForAll(address(harvest), true);

        uint256 gasStart = gasleft();
        harvest.batchSale(tokenTypes, tokenContracts, tokenIds, counts, false);
        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used by batchSale for ERC721:", gasUsed);

        vm.stopPrank();
    }

    function testGas_erc1155Sale() public {
        uint256[] memory tokenIds = new uint256[](100);
        uint256[] memory counts = new uint256[](100);
        for (uint256 i = 0; i < 100; i++) {
            tokenIds[i] = 1;
            counts[i] = 10;
        }

        harvest.setBarn(theBarn);

        vm.startPrank(user1);
        mock1155.setApprovalForAll(address(harvest), true);

        uint256 gasStart = gasleft();
        harvest.erc1155Sale(address(mock1155), tokenIds, counts, false);
        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used by erc1155Sale:", gasUsed);

        vm.stopPrank();
    }

    function testGas_batchSale_ERC1155() public {
        uint256 tokenCount = 100;
        TokenType[] memory tokenTypes = new TokenType[](tokenCount);
        address[] memory tokenContracts = new address[](tokenCount);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        uint256[] memory counts = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            tokenTypes[i] = TokenType.ERC1155;
            tokenContracts[i] = address(mock1155);
            tokenIds[i] = 1;
            counts[i] = 10;
        }

        harvest.setBarn(theBarn);

        vm.startPrank(user1);
        mock1155.setApprovalForAll(address(harvest), true);

        uint256 gasStart = gasleft();
        harvest.batchSale(tokenTypes, tokenContracts, tokenIds, counts, false);
        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used by batchSale for ERC1155:", gasUsed);

        vm.stopPrank();
    }

    function testGas_batchSale_ERC1155_Zeros() public {
        uint256 tokenCount = 100;
        TokenType[] memory tokenTypes = new TokenType[](tokenCount);
        address[] memory tokenContracts = new address[](tokenCount);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        uint256[] memory counts = new uint256[](tokenCount);

        tokenTypes[0] = TokenType.ERC1155;
        tokenContracts[0] = address(mock1155);
        tokenIds[0] = 1;
        counts[0] = 10;

        for (uint256 i = 1; i < tokenCount; i++) {
            tokenTypes[i] = TokenType.ERC1155;
            tokenContracts[i] = address(0);
            tokenIds[i] = 1;
            counts[i] = 10;
        }

        harvest.setBarn(theBarn);

        vm.startPrank(user1);
        mock1155.setApprovalForAll(address(harvest), true);

        uint256 gasStart = gasleft();
        harvest.batchSale(tokenTypes, tokenContracts, tokenIds, counts, false);
        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used by batchSale for ERC1155_Zeros:", gasUsed);

        vm.stopPrank();
    }

    function testGas_erc20Sale() public {
        uint256 amount = 1000;
        harvest.setBarn(theBarn);

        vm.startPrank(user1);
        mock20.approve(address(harvest), type(uint256).max);

        uint256 gasStart = gasleft();
        harvest.erc20Sale(address(mock20), amount, false);
        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used by erc20Sale:", gasUsed);

        vm.stopPrank();
    }

    function testGas_batchSale_ERC20() public {
        uint256 tokenCount = 100;
        TokenType[] memory tokenTypes = new TokenType[](tokenCount);
        address[] memory tokenContracts = new address[](tokenCount);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        uint256[] memory counts = new uint256[](tokenCount);

        for (uint256 i = 0; i < tokenCount; i++) {
            tokenTypes[i] = TokenType.ERC20;
            tokenContracts[i] = address(mock20);
            tokenIds[i] = 0;
            counts[i] = 10;
        }

        harvest.setBarn(theBarn);

        vm.startPrank(user1);
        mock20.approve(address(harvest), type(uint256).max);

        uint256 gasStart = gasleft();
        harvest.batchSale(tokenTypes, tokenContracts, tokenIds, counts, false);
        uint256 gasUsed = gasStart - gasleft();
        console.log("Gas used by batchSale for ERC20:", gasUsed);

        vm.stopPrank();
    }
}