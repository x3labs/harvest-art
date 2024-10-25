// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "forge-std/Test.sol";
import "../src/TicketDispenser.sol";
import "../src/BidTicket.sol";
import "solady/utils/MerkleProofLib.sol";
import "./lib/ERC1155ReceiverMock.sol";

contract TicketDispenserTest is Test {
    TicketDispenser public dispenser;
    BidTicket public bidTicket;
    address public owner;
    address public user1;
    address public user2;
    ERC1155ReceiverMock public receiverMock;
    
    // manually generated merkle root for testing.
    bytes32 constant MERKLE_ROOT = 0x5080172d5a6b3773332a1fed8f9eca9625f125684034b1c0541d806ea1d47239;
    uint256 constant TOKEN_ID = 1;
    uint256 constant DROP_ID = 1;
    uint256 constant AMOUNT = 100;
    
    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        
        receiverMock = new ERC1155ReceiverMock();
        bidTicket = new BidTicket(owner);
        dispenser = new TicketDispenser(owner, address(bidTicket));
        bidTicket.mint(address(dispenser), TOKEN_ID, AMOUNT * 3);
    }

    function testSetMerkleRoot() public {
        bytes32 newRoot = keccak256("new root");
        dispenser.setMerkleRoot(DROP_ID, newRoot);
        assertEq(dispenser.merkleRoots(DROP_ID), newRoot);
    }

    function testSetMerkleRootNotOwner() public {
        bytes32 newRoot = keccak256("new root");
        vm.prank(user1);
        vm.expectRevert();
        dispenser.setMerkleRoot(DROP_ID, newRoot);
    }

    function testClaim() public {
        bytes32[] memory proof = _getMerkleProof(user1, DROP_ID, TOKEN_ID, AMOUNT);
        dispenser.setMerkleRoot(DROP_ID, MERKLE_ROOT);

        vm.prank(user1);
        dispenser.claim(DROP_ID, TOKEN_ID, AMOUNT, proof);

        assertEq(bidTicket.balanceOf(user1, TOKEN_ID), AMOUNT);
        assertTrue(dispenser.hasClaimed(DROP_ID, user1));
    }

    function testClaimAlreadyClaimed() public {
        bytes32[] memory proof = _getMerkleProof(user1, DROP_ID, TOKEN_ID, AMOUNT);
        dispenser.setMerkleRoot(DROP_ID, MERKLE_ROOT);

        vm.prank(user1);
        dispenser.claim(DROP_ID, TOKEN_ID, AMOUNT, proof);

        vm.prank(user1);
        vm.expectRevert(TicketDispenser.AlreadyClaimed.selector);
        dispenser.claim(DROP_ID, TOKEN_ID, AMOUNT, proof);
    }

    function testMultipleDrops() public {
        uint256 DROP_ID_2 = 2;
        
        bytes32[] memory proof1 = _getMerkleProof(user1, DROP_ID, TOKEN_ID, AMOUNT);
        dispenser.setMerkleRoot(DROP_ID, MERKLE_ROOT);

        bytes32[] memory proof2 = _getMerkleProof(user1, DROP_ID_2, TOKEN_ID, AMOUNT);
        dispenser.setMerkleRoot(DROP_ID_2, MERKLE_ROOT);

        vm.startPrank(user1);
        dispenser.claim(DROP_ID, TOKEN_ID, AMOUNT, proof1);
        dispenser.claim(DROP_ID_2, TOKEN_ID, AMOUNT, proof2);
        vm.stopPrank();

        assertEq(bidTicket.balanceOf(user1, TOKEN_ID), AMOUNT * 2);
        assertTrue(dispenser.hasClaimed(DROP_ID, user1));
        assertTrue(dispenser.hasClaimed(DROP_ID_2, user1));
    }

    function testWithdrawTokens() public {
        uint256 initialBalance = bidTicket.balanceOf(owner, TOKEN_ID);
        dispenser.withdrawTokens(TOKEN_ID, AMOUNT);
        assertEq(bidTicket.balanceOf(owner, TOKEN_ID), initialBalance + AMOUNT);
    }

    function testWithdrawTokensNotOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        dispenser.withdrawTokens(TOKEN_ID, AMOUNT);
    }

    function testMerkleProofVerification() public view {
        address user = user1;
        uint256 dropId = DROP_ID;
        uint256 tokenId = TOKEN_ID;
        uint256 amount = AMOUNT;

        bytes32[] memory proof = _getMerkleProof(user, dropId, tokenId, amount);

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(user, dropId, tokenId, amount))));
        bool isValid = MerkleProofLib.verify(proof, MERKLE_ROOT, leaf);

        assertTrue(isValid, "Merkle proof should be valid");
    }

    function testERC1155Reception() public {
        uint256 amount = 10;
        vm.prank(owner);
        bidTicket.mint(address(receiverMock), TOKEN_ID, amount);
        assertEq(bidTicket.balanceOf(address(receiverMock), TOKEN_ID), amount);
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }    

    function _getMerkleProof(address user, uint256 dropId, uint256, uint256) internal pure returns (bytes32[] memory) {
        if (user == address(0x1) && dropId == 1) {
            bytes32[] memory proof = new bytes32[](3);
            proof[0] = 0xcd35f79aed5dc035016ebda6fa56b984234bc6c386f97b0d43e38645542c151a;
            proof[1] = 0x94f9bd05ebac1fa2bd9ff9b665d93a988913ad5358711cb566e6f23d8235952f;
            proof[2] = 0x061c2cd02556ed673ffd819b439b02ad65f2fd25bce181212080ab1ce4cb927b;
            return proof;
        } else if (user == address(0x2) && dropId == 1) {
            bytes32[] memory proof = new bytes32[](3);
            proof[0] = 0x26a9e76fb545cfc2a7d6b0f447b6506dbb6de24294b4990ba50474f72e38bf21;
            proof[1] = 0x929d09b952358b189ffcc18050b972c7b42c7fcab17b289e1dcb19408995d638;
            proof[2] = 0x061c2cd02556ed673ffd819b439b02ad65f2fd25bce181212080ab1ce4cb927b;
            return proof;
        } else if (user == address(0x1) && dropId == 2) {
            bytes32[] memory proof = new bytes32[](3);
            proof[0] = 0xe56242ad1daf47d0c131c9280ef92015600538081765f3d12fc237c364f8c499;
            proof[1] = 0x252018b801a2eddd27b2383a5e7d9110160f1cc0f82d21327ebd64924d9a2aa9;
            proof[2] = 0x6639811a983f623a2f61eaab176f291eba70f4c00eb7faf8e7325b8cbe86e3f0;
            return proof;
        } else {
            revert("Merkle proof not found for given parameters");
        }
    }

}
