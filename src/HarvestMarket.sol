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
    uint64 highestBid;
    uint64 endTime;
    bool claimed;
    bool withdrawn;
    mapping(uint8 => uint256) tokenIds;
    mapping(uint8 => uint8) amounts;
}

contract HarvestMarket is Ownable {
    IBidTicket public bidTicket;
    address public theBarn;
    uint8 public bidTicketTokenId = 1;
    uint8 public bidTicketCostStart = 5;
    uint8 public bidTicketCostBid = 1;
    uint8 public maxTokens = 50;
    uint32 public nextAuctionId = 1;
    uint64 public minStartPrice = 0.05 ether;
    uint64 public minBidIncrement = 0.01 ether;

    mapping(uint32 => Auction) public auctions;
    mapping(address => mapping(uint256 => bool)) public erc721Tokens;
    mapping(address => mapping(uint256 => uint256)) public erc1155Tokens;

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
            revert BidTooLow();
        }

        if (bidTicket.balanceOf(msg.sender, bidTicketTokenId) < bidTicketCostStart) {
            revert NotEnoughBidTickets();
        }

        bidTicket.burn(msg.sender, bidTicketTokenId, bidTicketCostStart);

        _validateTokens(tokenAddress, tokenIds, amounts);

        Auction storage auction = auctions[nextAuctionId];

        auction.tokenAddress = tokenAddress;
        auction.endTime = uint64(block.timestamp + 7 days);
        auction.highestBidder = msg.sender;
        auction.highestBid = uint64(msg.value);

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
        Auction storage auction = auctions[uint32(auctionId)];

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
        auction.highestBid = uint64(msg.value);

        emit NewBid(auctionId, msg.sender, msg.value);
    }

    function claim(uint256 auctionId) external {
        Auction storage auction = auctions[uint32(auctionId)];

        if (block.timestamp < auction.endTime) {
            revert AuctionNotEnded();
        }

        if (msg.sender != auction.highestBidder) {
            revert NotHighestBidder();
        }

        if (auction.claimed) {
            revert AuctionClaimed();
        }

        auctions[uint32(auctionId)].claimed = true;

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

    function withdraw(uint32[] memory auctionIds) external onlyOwner {
        uint256 totalAmount;

        for (uint32 i; i < auctionIds.length;) {
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

    function setBidTicketTokenId(uint8 bidTicketTokenId_) external onlyOwner {
        bidTicketTokenId = bidTicketTokenId_;
    }

    function setMaxTokens(uint8 maxTokens_) external onlyOwner {
        maxTokens = maxTokens_;
    }

    function setMinStartPrice(uint64 minStartPrice_) external onlyOwner {
        minStartPrice = minStartPrice_;
    }

    function setMinBidIncrement(uint64 minBidIncrement_) external onlyOwner {
        minBidIncrement = minBidIncrement_;
    }

    function _validateTokens(address tokenAddress, uint256[] calldata tokenIds, uint8[] calldata amounts) internal {
        IERCBase tokenContract = IERCBase(tokenAddress);

        if (tokenContract.supportsInterface(ERC721_INTERFACE)) {
            _validateERC721Tokens(tokenAddress, tokenIds);
        } else if (tokenContract.supportsInterface(ERC1155_INTERFACE)) {
            _validateERC1155Tokens(tokenAddress, tokenIds, amounts);
        } else {
            revert InvalidTokenAddress();
        }
    }

    function _validateERC721Tokens(address tokenAddress, uint256[] calldata tokenIds) internal {
        IERC721 erc721Contract = IERC721(tokenAddress);

        for (uint8 i; i < tokenIds.length;) {
            if (erc721Tokens[tokenAddress][tokenIds[i]]) {
                revert TokenAlreadyInAuction();
            }

            if (erc721Contract.ownerOf(tokenIds[i]) != theBarn) {
                revert TokenNotOwned();
            }

            unchecked {
                ++i;
            }
        }

        for (uint8 i; i < tokenIds.length;) {
            erc721Tokens[tokenAddress][tokenIds[i]] = true;

            unchecked {
                ++i;
            }
        }
    }

    function _validateERC1155Tokens(address tokenAddress, uint256[] calldata tokenIds, uint8[] calldata amounts)
        internal
    {
        IERC1155 erc1155Contract = IERC1155(tokenAddress);

        for (uint8 i; i < tokenIds.length;) {
            uint256 totalNeeded = erc1155Tokens[tokenAddress][tokenIds[i]] + amounts[i];
            uint256 balance = erc1155Contract.balanceOf(theBarn, tokenIds[i]);

            if (totalNeeded > balance) {
                revert NotEnoughTokensInSupply();
            }

            unchecked {
                erc1155Tokens[tokenAddress][tokenIds[i]] += amounts[i];
                ++i;
            }
        }
    }

    function _transferERC721s(Auction storage auction) internal {
        bool zeroInSet = false;
        uint8 i;

        while (true) {
            uint256 currentTokenId = auction.tokenIds[i];

            if (zeroInSet && currentTokenId == 0) {
                break;
            }

            erc721Tokens[auction.tokenAddress][currentTokenId] = false;
            IERC721(auction.tokenAddress).transferFrom(theBarn, auction.highestBidder, currentTokenId);

            if (currentTokenId == 0) {
                zeroInSet = true;
            }

            unchecked {
                ++i;
            }
        }
    }

    function _transferERC1155s(Auction storage auction) internal {
        uint256 prevTokenId = type(uint256).max;
        uint8 i;

        while (true) {
            uint256 currentTokenId = auction.tokenIds[i];

            if (prevTokenId == 0 && currentTokenId == 0) {
                break;
            }

            --erc1155Tokens[auction.tokenAddress][currentTokenId];
            IERC1155(auction.tokenAddress).safeTransferFrom(theBarn, auction.highestBidder, currentTokenId, 1, "");

            prevTokenId = currentTokenId;

            unchecked {
                ++i;
            }
        }
    }
}
