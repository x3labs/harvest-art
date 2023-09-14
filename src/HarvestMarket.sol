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
    uint256 highestBid;
    uint64 endTime;
    uint8 tokenCount;
    bool claimed;
    bool withdrawn;
    mapping(uint8 => uint256) tokenIds;
    mapping(uint8 => uint8) amounts;
}

contract HarvestMarket is Ownable {
    IBidTicket public bidTicket;
    address public theBarn;
    uint256 public bidTicketTokenId = 1;
    uint256 public bidTicketCostStart = 5;
    uint256 public bidTicketCostBid = 1;
    uint256 public maxTokens = 50;
    uint256 public nextAuctionId = 1;
    uint256 public minStartPrice = 0.05 ether;
    uint256 public minBidIncrement = 0.01 ether;

    mapping(uint256 => Auction) public auctions;
    mapping(address => mapping(uint256 => bool)) public auctionTokensERC721;
    mapping(address => mapping(uint256 => uint256)) public auctionTokensERC1155;

    error AuctionActive();
    error AuctionClaimed();
    error AuctionEnded();
    error AuctionNotEnded();
    error AuctionWithdrawn();
    error BidTooLow();
    error InvalidLengthOfAmounts();
    error InvalidLengthOfTokenIds();
    error InvalidTokenAddress();
    error NotApproved();
    error NotEnoughBidTickets();
    error NotEnoughTokensInSupply();
    error NotHighestBidder();
    error StartPriceTooLow();
    error TokenAlreadyInAuction();
    error TokenNotOwned();
    error TransferFailed();

    event AuctionStarted(address indexed bidder, address indexed tokenAddress, uint256[] indexed tokenIds);
    event Claimed(uint256 indexed auctionId, address indexed winner);
    event NewBid(uint256 indexed auctionId, address indexed bidder, uint256 indexed value);

    constructor(address theBarn_, address bidTicket_) {
        _initializeOwner(msg.sender);
        theBarn = theBarn_;
        bidTicket = IBidTicket(bidTicket_);
    }

    function startAuction(address tokenAddress, uint256[] calldata tokenIds, uint8[] calldata amounts)
        external
        payable
    {
        if (tokenIds.length > maxTokens || tokenIds.length == 0) {
            revert InvalidLengthOfTokenIds();
        }

        if (tokenIds.length != amounts.length) {
            revert InvalidLengthOfAmounts();
        }

        if (msg.value < minStartPrice) {
            revert StartPriceTooLow();
        }

        bidTicket.burn(msg.sender, bidTicketTokenId, bidTicketCostStart);

        _validateTokens(tokenAddress, tokenIds, amounts);

        Auction storage auction = auctions[nextAuctionId];

        auction.tokenAddress = tokenAddress;
        auction.endTime = uint64(block.timestamp + 7 days);
        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;
        auction.tokenCount = uint8(tokenIds.length);

        for (uint8 i; i < tokenIds.length;) {
            auction.tokenIds[i] = tokenIds[i];
            auction.amounts[i] = amounts[i];

            unchecked {
                ++i;
            }
        }

        unchecked {
            ++nextAuctionId;
        }

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

        bidTicket.burn(msg.sender, bidTicketTokenId, bidTicketCostBid);

        if (block.timestamp >= auction.endTime - 1 hours) {
            auction.endTime += 1 hours;
        }

        address prevHighestBidder = auction.highestBidder;
        uint256 prevHighestBid = auction.highestBid;

        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;

        if (prevHighestBidder != address(0)) {
            (bool success,) = payable(prevHighestBidder).call{value: prevHighestBid}("");
            if (!success) revert TransferFailed();
        }

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
            _transferERC721s(auction);
        } else if (tokenContract.supportsInterface(ERC1155_INTERFACE)) {
            _transferERC1155s(auction);
        } else {
            revert InvalidTokenAddress();
        }

        emit Claimed(auctionId, msg.sender);
    }

    function withdraw(uint256[] memory auctionIds) external onlyOwner {
        uint256 totalAmount;

        for (uint256 i; i < auctionIds.length;) {
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
                ++i;
            }
        }

        (bool success,) = payable(msg.sender).call{value: totalAmount}("");
        if (!success) revert TransferFailed();
    }

    function setBarnAddress(address theBarn_) external onlyOwner {
        theBarn = theBarn_;
    }

    function setBidTicketAddress(address bidTicket_) external onlyOwner {
        bidTicket = IBidTicket(bidTicket_);
    }

    function setBidTicketTokenId(uint256 bidTicketTokenId_) external onlyOwner {
        bidTicketTokenId = bidTicketTokenId_;
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

    function _validateTokens(address tokenAddress, uint256[] calldata tokenIds, uint8[] calldata amounts) internal {
        IERCBase tokenContract = IERCBase(tokenAddress);

        if (tokenContract.supportsInterface(ERC721_INTERFACE)) {
            _validateauctionTokensERC721(tokenAddress, tokenIds);
        } else if (tokenContract.supportsInterface(ERC1155_INTERFACE)) {
            _validateauctionTokensERC1155(tokenAddress, tokenIds, amounts);
        } else {
            revert InvalidTokenAddress();
        }
    }

    function _validateauctionTokensERC721(address tokenAddress, uint256[] calldata tokenIds) internal {
        IERC721 erc721Contract = IERC721(tokenAddress);
        uint256 tokenId;

        for (uint256 i; i < tokenIds.length;) {
            tokenId = tokenIds[i];

            if (auctionTokensERC721[tokenAddress][tokenId]) {
                revert TokenAlreadyInAuction();
            }

            auctionTokensERC721[tokenAddress][tokenId] = true;

            if (erc721Contract.ownerOf(tokenId) != theBarn) {
                revert TokenNotOwned();
            }

            unchecked {
                ++i;
            }
        }
    }

    function _validateauctionTokensERC1155(address tokenAddress, uint256[] calldata tokenIds, uint8[] calldata amounts)
        internal
    {
        IERC1155 erc1155Contract = IERC1155(tokenAddress);
        uint256 totalNeeded;
        uint256 balance;
        uint256 tokenId;
        uint8 amount;

        for (uint256 i; i < tokenIds.length;) {
            tokenId = tokenIds[i];
            amount = amounts[i];

            totalNeeded = auctionTokensERC1155[tokenAddress][tokenId] + amount;
            balance = erc1155Contract.balanceOf(theBarn, tokenId);

            if (totalNeeded > balance) {
                revert NotEnoughTokensInSupply();
            }

            unchecked {
                auctionTokensERC1155[tokenAddress][tokenId] += amount;
                ++i;
            }
        }
    }

    function _transferERC721s(Auction storage auction) internal {
        uint256 currentTokenId;
        IERC721 erc721Contract = IERC721(auction.tokenAddress);

        for (uint8 i; i < auction.tokenCount;) {
            currentTokenId = auction.tokenIds[i];

            auctionTokensERC721[auction.tokenAddress][currentTokenId] = false;
            erc721Contract.transferFrom(theBarn, auction.highestBidder, currentTokenId);

            unchecked {
                ++i;
            }
        }
    }

    function _transferERC1155s(Auction storage auction) internal {
        uint256 currentTokenId;
        IERC1155 erc1155Contract = IERC1155(auction.tokenAddress);

        for (uint8 i; i < auction.tokenCount;) {
            currentTokenId = auction.tokenIds[i];

            --auctionTokensERC1155[auction.tokenAddress][currentTokenId];
            erc1155Contract.safeTransferFrom(theBarn, auction.highestBidder, currentTokenId, 1, "");

            unchecked {
                ++i;
            }
        }
    }
}
