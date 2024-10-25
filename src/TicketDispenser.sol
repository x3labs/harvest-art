// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "../src/BidTicket.sol";
import "solady/auth/Ownable.sol";
import "solady/utils/MerkleProofLib.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract TicketDispenser is Ownable, ERC1155Holder {
    BidTicket public bidTicket;
    mapping(uint256 => bytes32) public merkleRoots;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;

    event TicketsClaimed(uint256 indexed dropId, address indexed claimer, uint256 tokenId, uint256 amount);

    error AlreadyClaimed();
    error InvalidProof();
    error InsufficientBalance();

    constructor(address owner_, address bidTicketAddress) {
        _initializeOwner(owner_);
        bidTicket = BidTicket(bidTicketAddress);
    }

    function claim(
        uint256 dropId,
        uint256 tokenId,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external {
        require(!hasClaimed[dropId][msg.sender], AlreadyClaimed());

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, dropId, tokenId, amount))));
        bool isValidProof = MerkleProofLib.verify(merkleProof, merkleRoots[dropId], leaf);

        require(isValidProof, InvalidProof());
        require(bidTicket.balanceOf(address(this), tokenId) >= amount, InsufficientBalance());

        hasClaimed[dropId][msg.sender] = true;

        emit TicketsClaimed(dropId, msg.sender, tokenId, amount);
        bidTicket.safeTransferFrom(address(this), msg.sender, tokenId, amount, "");
    }

    function withdrawTokens(uint256 tokenId, uint256 amount) external onlyOwner {
        bidTicket.safeTransferFrom(address(this), msg.sender, tokenId, amount, "");
    }

    function setMerkleRoot(uint256 dropId, bytes32 _merkleRoot) external onlyOwner {
        merkleRoots[dropId] = _merkleRoot;
    }
}
