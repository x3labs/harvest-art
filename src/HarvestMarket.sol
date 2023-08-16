// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//                            _.-^-._    .--.
//                         .-'   _   '-. |__|
//                        /     |_|     \|  |
//                       /               \  |
//                      /|     _____     |\ |
//                       |    |==|==|    |  |
//   |---|---|---|---|---|    |--|--|    |  |
//   |---|---|---|---|---|    |==|==|    |  |
//  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
//  _______  Harvest.art v3 (Market) _________

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "solady/src/auth/Ownable.sol";
import "../src/IBidTicket.sol";
import "../src/IERCBase.sol";

bytes4 constant ERC721_INTERFACE = 0x80ac58cd;
bytes4 constant ERC1155_INTERFACE = 0xd9b67a26;

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
    address public theBarn;
    IBidTicket public bidTicket;

    uint256 public minStartPrice = 0.05 ether;
    uint256 public minBidIncrement = 0.01 ether;
    uint256 public maxTokens = 50;
    uint256 public nextAuctionId = 1;
    uint256 public bidTicketTokenId = 1;
    uint256 public bidTicketCostStart = 10;
    uint256 public bidTicketCostBid = 1;

    mapping(uint256 => Auction) public auctions;

    error AuctionActive();
    error AuctionClaimed();
    error AuctionEnded();
    error AuctionNotEnded();
    error AuctionWithdrawn();
    error BidTooLow();
    error InvalidTokenAddress();
    error NotApproved();
    error NotEnoughBidTickets();
    error NotHighestBidder();
    error TooManyTokens();
    error TransferFailed();

    event AuctionStarted(address indexed bidder, address indexed tokenAddress, uint256[] indexed tokenIds);
    event Claimed(uint256 indexed auctionId, address indexed winner);
    event NewBid(uint256 indexed auctionId, address indexed bidder, uint256 indexed value);

    constructor(address theBarn_, address bidTicket_) {
        _initializeOwner(msg.sender);
        theBarn = theBarn_;
        bidTicket = IBidTicket(bidTicket_);
    }

    function startAuction(address tokenAddress, uint256[] calldata tokenIds) external payable {
        if (tokenIds.length > maxTokens) {
            revert TooManyTokens();
        }

        if (msg.value < minStartPrice) {
            revert BidTooLow();
        }

        if (bidTicket.balanceOf(msg.sender, bidTicketTokenId) < bidTicketCostStart) {
            revert NotEnoughBidTickets();
        }

        auctions[nextAuctionId] = Auction({
            tokenAddress: tokenAddress,
            tokenIds: tokenIds,
            endTime: block.timestamp + 7 days,
            highestBidder: msg.sender,
            highestBid: msg.value,
            claimed: false,
            withdrawn: false
        });

        unchecked {
            nextAuctionId++;
        }

        bidTicket.burn(msg.sender, bidTicketTokenId, bidTicketCostStart);

        emit AuctionStarted(msg.sender, tokenAddress, tokenIds);
    }

    function bid(uint256 auctionId) external payable {
        Auction storage auction = auctions[auctionId];

        if (block.timestamp >= auction.endTime) {
            revert AuctionEnded();
        }

        if (msg.value < auction.highestBid + minBidIncrement) {
            revert BidTooLow();
        }

        if (block.timestamp >= auction.endTime - 1 hours) {
            auction.endTime += 1 hours;
        }

        if (bidTicket.balanceOf(msg.sender, bidTicketTokenId) < bidTicketCostBid) {
            revert NotEnoughBidTickets();
        }

        bidTicket.burn(msg.sender, bidTicketTokenId, bidTicketCostBid);

        if (auction.highestBidder != address(0)) {
            (bool success,) = payable(auction.highestBidder).call{value: auction.highestBid}("");
            if (!success) revert TransferFailed();
        }

        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;

        emit NewBid(auctionId, msg.sender, msg.value);
    }

    function claim(uint256 auctionId) external {
        Auction storage auction = auctions[auctionId];

        if (block.timestamp < auction.endTime) {
            revert AuctionNotEnded();
        }

        if (msg.sender != auction.highestBidder) {
            revert NotHighestBidder();
        }

        if (auction.claimed) {
            revert AuctionClaimed();
        }

        auctions[auctionId].claimed = true;

        IERCBase tokenContract = IERCBase(auction.tokenAddress);

        if (tokenContract.supportsInterface(ERC721_INTERFACE)) {
            for (uint256 i = 0; i < auction.tokenIds.length;) {
                IERC721(auction.tokenAddress).transferFrom(theBarn, auction.highestBidder, auction.tokenIds[i]);

                unchecked {
                    i++;
                }
            }
        } else if (tokenContract.supportsInterface(ERC1155_INTERFACE)) {
            for (uint256 i = 0; i < auction.tokenIds.length;) {
                IERC1155(auction.tokenAddress).safeTransferFrom(
                    theBarn, auction.highestBidder, auction.tokenIds[i], 1, ""
                );

                unchecked {
                    i++;
                }
            }
        } else {
            revert InvalidTokenAddress();
        }

        (bool success,) = theBarn.call{value: auction.highestBid}("");
        if (!success) revert TransferFailed();

        emit Claimed(auctionId, msg.sender);
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
        if (!success) revert TransferFailed();
    }

    function setBarnAddress(address payable theBarn_) external onlyOwner {
        theBarn = theBarn_;
    }

    function setBidTicketAddress(address bidTicket_) external onlyOwner {
        bidTicket = IBidTicket(bidTicket_);
    }

    function setMaxTokens(uint256 maxTokens_) external onlyOwner {
        maxTokens = maxTokens_;
    }

    function setMinStartPrice(uint256 minStartPrice_) external onlyOwner {
        minStartPrice = minStartPrice_;
    }

    function setMinBidIncrement(uint256 minBidIncrement_) external onlyOwner {
        minBidIncrement = minBidIncrement_;
    }
}
