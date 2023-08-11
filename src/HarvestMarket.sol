// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

bytes4 constant _ERC721 = 0x80ac58cd;
bytes4 constant _ERC1155 = 0xd9b67a26;

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

struct Auction {
    address tokenAddress;
    address highestBidder;
    uint256 endTime;
    uint256 highestBid;
    bool claimed;
    bool withdrawn;
    uint256[] tokenIds;
}

contract HarvestMarket is Ownable {
    address payable public barnAddress;

    uint256 public minStartPrice = 0.05 ether;
    uint256 public minBidIncrement = 0.01 ether;
    uint256 public maxTokens = 50;
    uint256 public nextAuctionId = 1;

    mapping(uint256 => Auction) public auctions;

    error AuctionActive();
    error AuctionClaimed();
    error AuctionEnded();
    error AuctionNotEnded();
    error AuctionWithdrawn();
    error BidTooLow();
    error InvalidTokenAddress();
    error NotApproved();
    error NotHighestBidder();
    error TooManyTokens();
    error TransferFailed();

    event AuctionStarted(address indexed bidder, address indexed tokenAddress, uint256[] indexed tokenIds);
    event Claimed(uint256 indexed auctionId, address indexed winner);
    event NewBid(uint256 indexed auctionId, address indexed bidder, uint256 indexed value);

    function startAuction(address _tokenAddress, uint256[] calldata _tokenIds) external payable {
        if (_tokenIds.length > maxTokens) {
            revert TooManyTokens();
        }

        if (msg.value < minStartPrice) {
            revert BidTooLow();
        }

        auctions[nextAuctionId] = Auction({
            tokenAddress: _tokenAddress,
            tokenIds: _tokenIds,
            endTime: block.timestamp + 7 days,
            highestBidder: msg.sender,
            highestBid: msg.value,
            claimed: false,
            withdrawn: false
        });

        unchecked {
            nextAuctionId++;
        }

        emit AuctionStarted(msg.sender, _tokenAddress, _tokenIds);
    }

    function bid(uint256 _auctionId) external payable {
        Auction storage auction = auctions[_auctionId];

        if (block.timestamp >= auction.endTime) {
            revert AuctionEnded();
        }

        if (msg.value < auction.highestBid + minBidIncrement) {
            revert BidTooLow();
        }

        if (block.timestamp >= auction.endTime - 1 hours) {
            auction.endTime += 1 hours;
        }

        if (auction.highestBidder != address(0)) {
            (bool success,) = payable(auction.highestBidder).call{value: auction.highestBid}("");
            if (!success) revert TransferFailed();
        }

        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;

        emit NewBid(_auctionId, msg.sender, msg.value);
    }

    function claim(uint256 _auctionId) external {
        Auction storage auction = auctions[_auctionId];

        if (block.timestamp < auction.endTime) {
            revert AuctionNotEnded();
        }

        if (msg.sender != auction.highestBidder) {
            revert NotHighestBidder();
        }

        if (auction.claimed) {
            revert AuctionClaimed();
        }

        auctions[_auctionId].claimed = true;

        ERCBase tokenContract = ERCBase(auction.tokenAddress);

        if (tokenContract.supportsInterface(_ERC721)) {
            for (uint256 i = 0; i < auction.tokenIds.length;) {
                IERC721(auction.tokenAddress).transferFrom(barnAddress, auction.highestBidder, auction.tokenIds[i]);

                unchecked {
                    i++;
                }
            }
        } else if (tokenContract.supportsInterface(_ERC1155)) {
            for (uint256 i = 0; i < auction.tokenIds.length;) {
                IERC1155(auction.tokenAddress).safeTransferFrom(
                    barnAddress, auction.highestBidder, auction.tokenIds[i], 1, ""
                );

                unchecked {
                    i++;
                }
            }
        } else {
            revert InvalidTokenAddress();
        }

        (bool success,) = barnAddress.call{value: auction.highestBid}("");
        if (!success) revert TransferFailed();

        emit Claimed(_auctionId, msg.sender);
    }

    function withdraw(uint256[] memory auctionIds) external onlyOwner {
        uint256 totalAmount = 0;

        for (uint256 i = 0; i < auctionIds.length;) {
            Auction storage auction = auctions[auctionIds[i]];

            if (auction.withdrawn) {
                revert AuctionWithdrawn();
            }

            if (block.timestamp <= auction.endTime) {
                revert AuctionActive();
            }

            totalAmount += auction.highestBid;
            auctions[auctionIds[i]].withdrawn = true;

            unchecked {
                i++;
            }
        }

        (bool success,) = payable(msg.sender).call{value: totalAmount}("");
        require(success, "Transfer failed");
    }

    function setBarnAddress(address payable _barnAddress) external onlyOwner {
        barnAddress = _barnAddress;
    }

    function setMaxTokens(uint256 _maxTokens) external onlyOwner {
        maxTokens = _maxTokens;
    }

    function setMinStartPrice(uint256 _minStartPrice) external onlyOwner {
        minStartPrice = _minStartPrice;
    }

    function setMinBidIncrement(uint256 _minBidIncrement) external onlyOwner {
        minBidIncrement = _minBidIncrement;
    }
}
