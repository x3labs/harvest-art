// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface ERCBase {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function isApprovedForAll(address account, address operator) external view returns (bool);
}

interface ERC721Partial is ERCBase {
    function transferFrom(address from, address to, uint256 tokenId) external;
}

interface ERC1155Partial is ERCBase {
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata) external;
}

contract HarvestMarket is Ownable {
    using Address for address;

    struct Auction {
        address tokenAddress;
        address highestBidder;
        uint256 startTime;
        uint256 endTime;
        uint256 startPrice;
        uint256 highestBid;
        uint256[] tokenIds;
        uint256[] amounts;
    }

    bytes4 _ERC721 = 0x80ac58cd;
    bytes4 _ERC1155 = 0xd9b67a26;

    address payable public BarnAddress;

    uint256 public constant MINIMUM_START_PRICE = 0.05 ether;
    uint256 public constant MINIMUM_BID_INCREMENT = 0.01 ether;
    uint256 public maxTokens = 1000;
    uint256 public nextAuctionId = 1;

    mapping(uint256 => Auction) public auctions;

    error AuctionEnded();
    error AuctionNotEnded();
    error BidTooLow();
    error InvalidTokenAddress();
    error NotApproved();
    error NotHighestBidder();
    error TooManyTokens();
    error TransferFailed();

    function createAuction(address _tokenAddress, uint256[] calldata _tokenIds, uint256[] calldata _amounts)
        external
        payable
    {
        if (_tokenIds.length > maxTokens) {
            revert TooManyTokens();
        }

        if (msg.value < MINIMUM_START_PRICE) {
            revert BidTooLow();
        }

        auctions[nextAuctionId] = Auction({
            tokenAddress: _tokenAddress,
            tokenIds: _tokenIds,
            amounts: _amounts,
            startTime: block.timestamp,
            endTime: block.timestamp + 7 days,
            startPrice: msg.value,
            highestBidder: msg.sender,
            highestBid: msg.value
        });

        nextAuctionId++;
    }

    function bid(uint256 _auctionId) external payable {
        Auction storage auction = auctions[_auctionId];

        if (block.timestamp >= auction.endTime) {
            revert AuctionEnded();
        }

        if (msg.value < auction.highestBid + MINIMUM_BID_INCREMENT) {
            revert BidTooLow();
        }

        if (auction.highestBidder != address(0)) {
            (bool success,) = payable(auction.highestBidder).call{value: auction.highestBid}("");
            if (!success) revert TransferFailed();
        }

        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;
    }

    function claim(uint256 _auctionId) external {
        Auction storage auction = auctions[_auctionId];

        if (block.timestamp < auction.endTime) {
            revert AuctionNotEnded();
        }

        if (msg.sender != auction.highestBidder) {
            revert NotHighestBidder();
        }

        ERCBase tokenContract = ERCBase(auction.tokenAddress);

        for (uint256 i = 0; i < auction.tokenIds.length;) {
            if (tokenContract.supportsInterface(_ERC721)) {
                IERC721(auction.tokenAddress).transferFrom(BarnAddress, auction.highestBidder, auction.tokenIds[i]);
            } else if (tokenContract.supportsInterface(_ERC1155)) {
                IERC1155(auction.tokenAddress).safeTransferFrom(
                    BarnAddress, auction.highestBidder, auction.tokenIds[i], auction.amounts[i], ""
                );
            } else {
                revert InvalidTokenAddress();
            }

            unchecked {
                i++;
            }
        }

        (bool success,) = BarnAddress.call{value: auction.highestBid}("");
        if (!success) revert TransferFailed();

        delete auctions[_auctionId];
    }

    function withdraw() external onlyOwner {
        (bool success,) = payable(msg.sender).call{value: address(this).balance}("");
        if (!success) revert TransferFailed();
    }

    function setBarnAddress(address payable _barnAddress) external onlyOwner {
        BarnAddress = _barnAddress;
    }

    function setMaxTokens(uint256 _maxTokens) external onlyOwner {
        maxTokens = _maxTokens;
    }
}
