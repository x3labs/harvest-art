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
import "./IBidTicket.sol";

struct Auction {
    uint8 auctionType;
    address tokenAddress;
    uint64 endTime;
    uint8 tokenCount;
    bool claimed;
    bool withdrawn;
    address highestBidder;
    uint256 highestBid;
    mapping(uint256 => uint256) tokenIds;
    mapping(uint256 => uint256) amounts;
}

contract Market is Ownable {
    uint8 private constant AUCTION_TYPE_ERC721 = 0;
    uint8 private constant AUCTION_TYPE_ERC1155 = 0;

    IBidTicket public bidTicket;

    address public theBarn;
    uint256 public bidTicketTokenId = 1;
    uint256 public bidTicketCostStart = 5;
    uint256 public bidTicketCostBid = 1;
    uint256 public maxTokens = 50;
    uint256 public nextAuctionId = 1;
    uint256 public minStartPrice = 0.05 ether;
    uint256 public minBidIncrement = 0.01 ether;
    uint256 public auctionDuration = 7 days;

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
    error MaxTokensPerTxReached();
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

    /**
     *
     * startAuction - Starts an auction for a given token
     *
     * @param tokenAddress - The address of the token contract
     * @param tokenIds - The token ids to auction
     *
     */

    function startAuctionERC721(address tokenAddress, uint256[] calldata tokenIds)
        external
        payable
    {
        if (msg.value < minStartPrice) {
            revert StartPriceTooLow();
        }

        bidTicket.burn(msg.sender, bidTicketTokenId, bidTicketCostStart);

        _validateAuctionTokensERC721(tokenAddress, tokenIds);

        Auction storage auction = auctions[nextAuctionId];

        auction.auctionType = AUCTION_TYPE_ERC721;
        auction.tokenAddress = tokenAddress;
        auction.endTime = uint64(block.timestamp + auctionDuration);
        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;
        auction.tokenCount = uint8(tokenIds.length);

        mapping(uint256 => uint256) storage tokenMap = auction.tokenIds;
        for (uint256 i; i < tokenIds.length;) {
            tokenMap[i] = tokenIds[i];

            unchecked {
                ++i;
            }
        }

        unchecked {
            ++nextAuctionId;
        }

        emit AuctionStarted(msg.sender, tokenAddress, tokenIds);
    }

    /**
     *
     * startAuction - Starts an auction for a given token
     *
     * @param tokenAddress - The address of the token contract
     * @param tokenIds - The token ids to auction
     * @param amounts - The amounts of each token to auction
     *
     */

    function startAuctionERC1155(address tokenAddress, uint256[] calldata tokenIds, uint256[] calldata amounts)
        external
        payable
    {
        if (msg.value < minStartPrice) {
            revert StartPriceTooLow();
        }

        bidTicket.burn(msg.sender, bidTicketTokenId, bidTicketCostStart);

        _validateAuctionTokensERC1155(tokenAddress, tokenIds, amounts);

        Auction storage auction = auctions[nextAuctionId];

        auction.auctionType = AUCTION_TYPE_ERC1155;
        auction.tokenAddress = tokenAddress;
        auction.endTime = uint64(block.timestamp + auctionDuration);
        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;
        auction.tokenCount = uint8(tokenIds.length);

        mapping(uint256 => uint256) storage tokenMap = auction.tokenIds;
        mapping(uint256 => uint256) storage amountMap = auction.amounts;
        for (uint256 i; i < tokenIds.length;) {
            tokenMap[i] = tokenIds[i];
            amountMap[i] = amounts[i];

            unchecked {
                ++i;
            }
        }

        unchecked {
            ++nextAuctionId;
        }

        emit AuctionStarted(msg.sender, tokenAddress, tokenIds);
    }

    /**
     * bid - Places a bid on an auction
     *
     * @param auctionId - The id of the auction to bid on
     *
     */

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

        address prevHighestBidder = auction.highestBidder;
        uint256 prevHighestBid = auction.highestBid;

        auction.highestBidder = msg.sender;
        auction.highestBid = msg.value;

        bidTicket.burn(msg.sender, bidTicketTokenId, bidTicketCostBid);

        if (prevHighestBidder != address(0)) {
            (bool success,) = payable(prevHighestBidder).call{value: prevHighestBid}("");
            if (!success) revert TransferFailed();
        }

        emit NewBid(auctionId, msg.sender, msg.value);
    }

    /**
     * claim - Claims the tokens from an auction
     *
     * @param auctionId - The id of the auction to claim
     *
     */

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

        auction.claimed = true;

        if (auction.auctionType == AUCTION_TYPE_ERC721) {
            _transferERC721s(auction);
        } else {
            _transferERC1155s(auction);
        }

        emit Claimed(auctionId, msg.sender);
    }

    /**
     * withdraw - Withdraws the highest bid from an auction
     *
     * @param auctionIds - The ids of the auctions to withdraw from
     *
     * @notice - Auctions can only be withdrawn from after they have ended
     *
     */

    function withdraw(uint256[] calldata auctionIds) external onlyOwner {
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
            auction.withdrawn = true;

            unchecked {
                ++i;
            }
        }

        (bool success,) = payable(msg.sender).call{value: totalAmount}("");
        if (!success) revert TransferFailed();
    }

    /**
     *
     * Getters & Setters
     *
     */

    function getAuctionTokens(uint256 auctionId) external view returns (uint256[] memory, uint256[] memory) {
        Auction storage auction = auctions[auctionId];

        uint256[] memory tokenIds = new uint256[](auction.tokenCount);
        uint256[] memory amounts = new uint256[](auction.tokenCount);

        uint256 tokenCount = auction.tokenCount;
        for (uint256 i; i < tokenCount;) {
            tokenIds[i] = auction.tokenIds[i];
            if (auction.auctionType == AUCTION_TYPE_ERC721) {
                amounts[i] = 1;
            } else {
                amounts[i] = auction.amounts[i];
            }

            unchecked {
                ++i;
            }
        }

        return (tokenIds, amounts);
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

    function setAuctionDuration(uint256 auctionDuration_) external onlyOwner {
        auctionDuration = auctionDuration_;
    }

    /**
     *
     * Internal Functions
     *
     */

    function _validateAuctionTokensERC721(address tokenAddress, uint256[] calldata tokenIds) internal {
        if (tokenIds.length == 0) {
            revert InvalidLengthOfTokenIds();
        }

        IERC721 erc721Contract = IERC721(tokenAddress);

        if (tokenIds.length > maxTokens) {
            revert MaxTokensPerTxReached();
        }

        mapping(uint256 => bool) storage auctionTokens = auctionTokensERC721[tokenAddress];

        for (uint256 i; i < tokenIds.length;) {
            uint256 tokenId = tokenIds[i];

            if (auctionTokens[tokenId]) {
                revert TokenAlreadyInAuction();
            }

            auctionTokens[tokenId] = true;

            if (erc721Contract.ownerOf(tokenId) != theBarn) {
                revert TokenNotOwned();
            }

            unchecked {
                ++i;
            }
        }
    }

    function _validateAuctionTokensERC1155(
        address tokenAddress,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts
    ) internal {
        if (tokenIds.length == 0) {
            revert InvalidLengthOfTokenIds();
        }
        if (tokenIds.length != amounts.length) {
            revert InvalidLengthOfAmounts();
        }

        IERC1155 erc1155Contract = IERC1155(tokenAddress);
        uint256 totalTokens;
        uint256 totalNeeded;
        uint256 balance;
        uint256 tokenId;
        uint256 amount;

        mapping(uint256 => uint256) storage auctionTokens = auctionTokensERC1155[tokenAddress];

        for (uint256 i; i < tokenIds.length;) {
            tokenId = tokenIds[i];
            amount = amounts[i];

            totalTokens += amount;
            totalNeeded = auctionTokens[tokenId] + amount;
            balance = erc1155Contract.balanceOf(theBarn, tokenId);

            if (totalNeeded > balance) {
                revert NotEnoughTokensInSupply();
            }

            unchecked {
                auctionTokens[tokenId] += amount;
                ++i;
            }
        }

        if (totalTokens > maxTokens) {
            revert MaxTokensPerTxReached();
        }
    }

    function _transferERC721s(Auction storage auction) internal {
        address tokenAddress = auction.tokenAddress;
        address highestBidder = auction.highestBidder;
        IERC721 erc721Contract = IERC721(tokenAddress);

        mapping(uint256 => uint256) storage tokenMap = auction.tokenIds;
        mapping(uint256 => bool) storage auctionTokens = auctionTokensERC721[tokenAddress];

        uint256 tokenCount = auction.tokenCount;
        for (uint256 i; i < tokenCount;) {
            uint256 tokenId = tokenMap[i];
            auctionTokens[tokenId] = false;
            erc721Contract.transferFrom(theBarn, highestBidder, tokenId);

            unchecked {
                ++i;
            }
        }
    }

    function _transferERC1155s(Auction storage auction) internal {
        address tokenAddress = auction.tokenAddress;
        IERC1155 erc1155Contract = IERC1155(tokenAddress);
        uint256[] memory tokenIds = new uint256[](auction.tokenCount);
        uint256[] memory amounts = new uint256[](auction.tokenCount);

        mapping(uint256 => uint256) storage tokenMap = auction.tokenIds;
        mapping(uint256 => uint256) storage amountMap = auction.amounts;
        mapping(uint256 => uint256) storage auctionTokens = auctionTokensERC1155[tokenAddress];

        uint256 tokenCount = auction.tokenCount;
        for (uint256 i; i < tokenCount;) {
            uint256 tokenId = tokenMap[i];
            uint256 amount = amountMap[i];

            tokenIds[i] = tokenId;
            amounts[i] = amount;
            auctionTokens[tokenId] -= amount;

            unchecked {
                ++i;
            }
        }

        erc1155Contract.safeBatchTransferFrom(theBarn, auction.highestBidder, tokenIds, amounts, "");
    }
}