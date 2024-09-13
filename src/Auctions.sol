// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

//                            _.-^-._    .--.
//                         .-'   _   '-. |__|
//                        /     |_|     \|  |
//                       /               \  |
//                      /|     _____     |\ |
//                       |    |==|==|    |  |
//   |---|---|---|---|---|    |--|--|    |  |
//   |---|---|---|---|---|    |==|==|    |  |
//  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
//  _______  Harvest.art v3.1 (Auctions) _________

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "solady/src/auth/Ownable.sol";
import "solady/src/utils/ReentrancyGuard.sol";
import "./IAuctions.sol";
import "./IBidTicket.sol";

enum Status {
    Active,
    Claimed,
    Refunded,
    Abandoned
}

struct Auction {
    uint8 auctionType;
    address tokenAddress;
    uint64 endTime;
    uint8 tokenCount;
    Status status;
    address highestBidder;
    uint256 highestBid;
    uint256 bidDelta;
    uint256 bidderCount;
    mapping(uint256 => address) bidders;
    mapping(uint256 => uint256) tokenIds;
    mapping(uint256 => uint256) amounts;
    mapping(address => uint256) rewards;
}

contract Auctions is IAuctions, Ownable, ReentrancyGuard {
    uint8 private constant AUCTION_TYPE_ERC721 = 0;
    uint8 private constant AUCTION_TYPE_ERC1155 = 1;

    IBidTicket public bidTicket;
    address public theBarn;
    address public theFarmer;
    uint256 public abandonmentFeePercent = 20;
    uint256 public antiSnipeDuration = 1 hours;
    uint256 public auctionDuration = 3 days;
    uint256 public bidTicketCostBid = 1;
    uint256 public bidTicketCostStart = 1;
    uint256 public bidTicketTokenId = 1;
    uint256 public maxTokens = 50;
    uint256 public minBidIncrement = 0.01 ether;
    uint256 public minStartingBid = 0.05 ether;
    uint256 public nextAuctionId = 1;
    uint256 public outbidRewardPercent = 10;
    uint256 public settlementDuration = 7 days;

    mapping(address => uint256) public balances;
    mapping(uint256 => Auction) public auctions;
    mapping(address => mapping(uint256 => bool)) public auctionTokensERC721;
    mapping(address => mapping(uint256 => uint256)) public auctionTokensERC1155;

    constructor(
        address owner_,
        address theBarn_,
        address theFarmer_,
        address bidTicket_
    ) {
        _initializeOwner(owner_);
        theBarn = theBarn_;
        theFarmer = theFarmer_;
        bidTicket = IBidTicket(bidTicket_);
    }

    /**
     *
     * startAuction - Starts an auction for a given token
     *
     * @param startingBid - The starting bid for the auction
     * @param tokenAddress - The address of the token contract
     * @param tokenIds - The token ids to auction
     *
     */

    function startAuctionERC721(
        uint256 startingBid,
        address tokenAddress,
        uint256[] calldata tokenIds
    ) external payable nonReentrant {
        if (startingBid < minStartingBid) revert StartPriceTooLow();
        if (tokenIds.length == 0) revert InvalidLengthOfTokenIds();
        if (tokenIds.length > maxTokens) revert MaxTokensPerTxReached();

        _processPayment(startingBid);

        Auction storage auction = auctions[nextAuctionId];

        auction.auctionType = AUCTION_TYPE_ERC721;
        auction.tokenAddress = tokenAddress;
        auction.endTime = uint64(block.timestamp + auctionDuration);
        auction.highestBidder = msg.sender;
        auction.highestBid = startingBid;
        auction.tokenCount = uint8(tokenIds.length);
        auction.bidderCount = 1;
        auction.bidDelta = startingBid;

        mapping(uint256 => uint256) storage tokenMap = auction.tokenIds;

        for (uint256 i; i < tokenIds.length; ++i) {
            tokenMap[i] = tokenIds[i];
        }

        unchecked {
            ++nextAuctionId;
        }

        emit Started(msg.sender, tokenAddress, tokenIds);
        
        bidTicket.burn(msg.sender, bidTicketTokenId, bidTicketCostStart);

        _validateAuctionTokensERC721(tokenAddress, tokenIds);
    }

    /**
     *
     * startAuction - Starts an auction for a given token
     *
     * @param startingBid - The starting bid for the auction
     * @param tokenAddress - The address of the token contract
     * @param tokenIds - The token ids to auction
     * @param amounts - The amounts of each token to auction
     *
     */

    function startAuctionERC1155(
        uint256 startingBid,
        address tokenAddress,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts
    ) external payable nonReentrant {
        if (startingBid < minStartingBid) revert StartPriceTooLow();
        if (tokenIds.length == 0) revert InvalidLengthOfTokenIds();
        if (tokenIds.length != amounts.length) revert InvalidLengthOfAmounts();

        _processPayment(startingBid);

        Auction storage auction = auctions[nextAuctionId];

        auction.auctionType = AUCTION_TYPE_ERC1155;
        auction.tokenAddress = tokenAddress;
        auction.endTime = uint64(block.timestamp + auctionDuration);
        auction.highestBidder = msg.sender;
        auction.highestBid = startingBid;
        auction.tokenCount = uint8(tokenIds.length);
        auction.bidderCount = 1;
        auction.bidDelta = startingBid;

        mapping(uint256 => uint256) storage tokenMap = auction.tokenIds;
        mapping(uint256 => uint256) storage amountMap = auction.amounts;

        for (uint256 i; i < tokenIds.length; ++i) {
            tokenMap[i] = tokenIds[i];
            amountMap[i] = amounts[i];
        }

        unchecked {
            ++nextAuctionId;
        }

        emit Started(msg.sender, tokenAddress, tokenIds);

        bidTicket.burn(msg.sender, bidTicketTokenId, bidTicketCostStart);

        _validateAuctionTokensERC1155(tokenAddress, tokenIds, amounts);
    }

    /**
     * bid - Places a bid on an auction
     *
     * @param auctionId - The id of the auction to bid on
     * @param bidAmount - The amount of the bid
     *
     */

    function bid(uint256 auctionId, uint256 bidAmount) external payable nonReentrant {
        Auction storage auction = auctions[auctionId];

        if (auction.status != Status.Active) revert InvalidStatus();
        if (auction.highestBidder == msg.sender) revert IsHighestBidder();
        if (bidAmount < auction.highestBid + minBidIncrement) revert BidTooLow();
        if (block.timestamp > auction.endTime) revert AuctionEnded();

        if (block.timestamp > auction.endTime - antiSnipeDuration) {
            auction.endTime += uint64(antiSnipeDuration);
        }

        _processPayment(bidAmount);

        address prevHighestBidder = auction.highestBidder;
        uint256 prevHighestBid = auction.highestBid;

        unchecked {
            // Return the previous bidder's bid to their balance
            balances[prevHighestBidder] += prevHighestBid;

            // Add new bidder to the bidders list
            if (auction.rewards[prevHighestBidder] == 0) {
                auction.bidders[auction.bidderCount - 1] = prevHighestBidder;
                ++auction.bidderCount;
            }

            // Calculate the reward for user who was outbid
            uint256 reward = auction.bidDelta * outbidRewardPercent / 100;
            auction.rewards[prevHighestBidder] += reward;

            // Update the bid delta for future potential outbids
            auction.bidDelta = bidAmount - prevHighestBid;
        }

        auction.highestBidder = msg.sender;
        auction.highestBid = bidAmount;

        emit NewBid(auctionId, msg.sender, bidAmount);

        bidTicket.burn(msg.sender, bidTicketTokenId, bidTicketCostBid);
    }

    /**
     * claim - Claims the tokens from an auction
     *
     * @param auctionId - The id of the auction to claim
     *
     */

    function claim(uint256 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];

        if (auction.status != Status.Active) revert InvalidStatus();
        if (block.timestamp <= auction.endTime) revert AuctionNotEnded();
        if (msg.sender != auction.highestBidder && msg.sender != owner()) revert NotHighestBidder();

        auction.status = Status.Claimed;

        uint256 totalRewards = _distributeRewards(auction);

        emit Claimed(auctionId, auction.highestBidder);

        (bool success,) = payable(theFarmer).call{value: auction.highestBid - totalRewards}("");
        if (!success) revert TransferFailed();
        
        if (auction.auctionType == AUCTION_TYPE_ERC721) {
            _transferERC721s(auction);
        } else {
            _transferERC1155s(auction);
        }
    }

    /**
     * refund - Refunds are available during the settlement period if The Barn has not yet approved the collection
     *
     * @param auctionId - The id of the auction to refund
     *
     */

    function refund(uint256 auctionId) external nonReentrant {
        Auction storage auction = auctions[auctionId];
        uint256 highestBid = auction.highestBid;
        uint256 endTime = auction.endTime;

        if (auction.status != Status.Active) revert InvalidStatus();
        if (block.timestamp <= endTime) revert AuctionActive();
        if (block.timestamp > endTime + settlementDuration) revert SettlementPeriodEnded();
        if (msg.sender != auction.highestBidder && msg.sender != owner()) revert NotHighestBidder();

        auction.status = Status.Refunded;

        emit Refunded(auctionId, auction.highestBidder, highestBid);

        if (auction.auctionType == AUCTION_TYPE_ERC721) {
            _checkAndResetERC721s(auction);
        } else {
            _checkAndResetERC1155s(auction);
        }

        unchecked {
            balances[auction.highestBidder] += highestBid;
        }
    }

    /**
     *
     * abandon - Mark unclaimed auctions as abandoned after the settlement period
     *
     * @param auctionId - The id of the auction to abandon
     *
     */
    function abandon(uint256 auctionId) external onlyOwner nonReentrant {
        Auction storage auction = auctions[auctionId];
        address highestBidder = auction.highestBidder;
        uint256 highestBid = auction.highestBid;

        if (auction.status != Status.Active) revert InvalidStatus();
        if (block.timestamp <= auction.endTime + settlementDuration) revert SettlementPeriodNotExpired();

        auction.status = Status.Abandoned;

        if (auction.auctionType == AUCTION_TYPE_ERC721) {
            _resetERC721s(auction);
        } else {
            _resetERC1155s(auction);
        }

        uint256 fee;

        unchecked {
            fee = highestBid * abandonmentFeePercent / 100;
            balances[highestBidder] += highestBid - fee;
        }

        emit Abandoned(auctionId, highestBidder, fee);

        (bool success,) = payable(theFarmer).call{value: fee}("");
        if (!success) revert TransferFailed();
    }

    /**
     * withdraw - Withdraws the balance of the user.
     *
     * @notice - We keep track of the balance instead of sending it directly
     *           back to the user when outbid to avoid certain types of attacks.
     *
     */
    function withdraw() external nonReentrant {
        uint256 balance = balances[msg.sender];

        if (balance == 0) revert NoBalanceToWithdraw();

        balances[msg.sender] = 0;

        emit Withdraw(msg.sender, balance);

        (bool success,) = payable(msg.sender).call{value: balance}("");
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

        for (uint256 i; i < tokenCount; ++i) {
            tokenIds[i] = auction.tokenIds[i];

            if (auction.auctionType == AUCTION_TYPE_ERC721) {
                amounts[i] = 1;
            } else {
                amounts[i] = auction.amounts[i];
            }
        }

        return (tokenIds, amounts);
    }

    function getPendingRewards(address bidder, uint256[] calldata auctionIds) external view returns (uint256) {
        uint256 totalRewards;

        for (uint256 i; i < auctionIds.length; ++i) {
            if (auctions[auctionIds[i]].status == Status.Active) {
                totalRewards += auctions[auctionIds[i]].rewards[bidder];
            }
        }

        return totalRewards;
    }

    function getClaimedAuctions(uint256 limit) external view returns (uint256[] memory) {
        uint256[] memory claimedAuctions = new uint256[](limit);
        uint256 count = 0;

        for (uint256 i = nextAuctionId - 1; i > 0 && count < limit; --i) {
            if (auctions[i].status == Status.Claimed) {
                claimedAuctions[count] = i;
                unchecked { ++count; }
            }
        }

        assembly {
            mstore(claimedAuctions, count)
        }

        return claimedAuctions;
    }

    function setBarnAddress(address theBarn_) external onlyOwner {
        theBarn = theBarn_;
    }

    function setFarmerAddress(address theFarmer_) external onlyOwner {
        theFarmer = theFarmer_;
    }

    function setBidTicketAddress(address bidTicket_) external onlyOwner {
        bidTicket = IBidTicket(bidTicket_);
    }

    function setBidTicketTokenId(uint256 bidTicketTokenId_) external onlyOwner {
        bidTicketTokenId = bidTicketTokenId_;
    }

    function setBidTicketCostStart(uint256 bidTicketCostStart_) external onlyOwner {
        bidTicketCostStart = bidTicketCostStart_;
    }

    function setBidTicketCostBid(uint256 bidTicketCostBid_) external onlyOwner {
        bidTicketCostBid = bidTicketCostBid_;
    }

    function setMaxTokens(uint256 maxTokens_) external onlyOwner {
        maxTokens = maxTokens_;
    }

    function setMinStartingBid(uint256 minStartingBid_) external onlyOwner {
        minStartingBid = minStartingBid_;
    }

    function setMinBidIncrement(uint256 minBidIncrement_) external onlyOwner {
        minBidIncrement = minBidIncrement_;
    }

    function setAuctionDuration(uint256 auctionDuration_) external onlyOwner {
        auctionDuration = auctionDuration_;
    }

    function setSettlementDuration(uint256 settlementDuration_) external onlyOwner {
        settlementDuration = settlementDuration_;
    }

    function setAntiSnipeDuration(uint256 antiSnipeDuration_) external onlyOwner {
        antiSnipeDuration = antiSnipeDuration_;
    }

    function setAbandonmentFeePercent(uint256 newFeePercent) external onlyOwner {
        if (newFeePercent > 100) revert InvalidFeePercentage();
        abandonmentFeePercent = newFeePercent;
    }

    function setOutbidRewardPercent(uint256 newPercent) external onlyOwner {
        if (newPercent > 100) revert InvalidFeePercentage();
        outbidRewardPercent = newPercent;
    }

    /**
     *
     * Internal Functions
     *
     */

    function _processPayment(uint256 payment) internal {
        uint256 balance = balances[msg.sender];
        uint256 paymentFromBalance;
        uint256 paymentFromMsgValue;

        if (balance >= payment) {
            paymentFromBalance = payment;
            paymentFromMsgValue = 0;
        } else {
            paymentFromBalance = balance;
            paymentFromMsgValue = payment - balance;
        }

        if (msg.value != paymentFromMsgValue) revert InvalidValue();

        if (paymentFromBalance > 0) {
            balances[msg.sender] -= paymentFromBalance;
        }
    }

    function _validateAuctionTokensERC721(address tokenAddress, uint256[] calldata tokenIds) internal {
        IERC721 erc721Contract = IERC721(tokenAddress);

        mapping(uint256 => bool) storage auctionTokens = auctionTokensERC721[tokenAddress];

        for (uint256 i; i < tokenIds.length; ++i) {
            uint256 tokenId = tokenIds[i];

            if (auctionTokens[tokenId]) revert TokenAlreadyInAuction();

            auctionTokens[tokenId] = true;

            if (erc721Contract.ownerOf(tokenId) != theBarn) revert TokenNotOwned();
        }
    }

    function _validateAuctionTokensERC1155(
        address tokenAddress,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts
    ) internal {
        IERC1155 erc1155Contract = IERC1155(tokenAddress);
        uint256 totalTokens;
        uint256 totalNeeded;
        uint256 balance;
        uint256 tokenId;
        uint256 amount;

        mapping(uint256 => uint256) storage auctionTokens = auctionTokensERC1155[tokenAddress];

        for (uint256 i; i < tokenIds.length; ++i) {
            tokenId = tokenIds[i];
            amount = amounts[i];

            totalTokens += amount;
            totalNeeded = auctionTokens[tokenId] + amount;
            balance = erc1155Contract.balanceOf(theBarn, tokenId);

            if (totalNeeded > balance) revert NotEnoughTokensInSupply();

            unchecked {
                auctionTokens[tokenId] += amount;
            }
        }

        if (totalTokens > maxTokens) revert MaxTokensPerTxReached();
    }

    function _transferERC721s(Auction storage auction) internal {
        address tokenAddress = auction.tokenAddress;
        uint256 tokenCount = auction.tokenCount;
        address highestBidder = auction.highestBidder;
        IERC721 erc721Contract = IERC721(tokenAddress);

        mapping(uint256 => uint256) storage tokenMap = auction.tokenIds;
        mapping(uint256 => bool) storage auctionTokens = auctionTokensERC721[tokenAddress];

        for (uint256 i; i < tokenCount; ++i) {
            auctionTokens[tokenMap[i]] = false;
        }

        for (uint256 i; i < tokenCount; ++i) {
            erc721Contract.safeTransferFrom(theBarn, highestBidder, tokenMap[i]);
        }
    }

    function _transferERC1155s(Auction storage auction) internal {
        address tokenAddress = auction.tokenAddress;
        IERC1155 erc1155Contract = IERC1155(tokenAddress);
        uint256 tokenCount = auction.tokenCount;
        uint256[] memory tokenIds = new uint256[](tokenCount);
        uint256[] memory amounts = new uint256[](tokenCount);

        mapping(uint256 => uint256) storage tokenMap = auction.tokenIds;
        mapping(uint256 => uint256) storage amountMap = auction.amounts;
        mapping(uint256 => uint256) storage auctionTokens = auctionTokensERC1155[tokenAddress];

        for (uint256 i; i < tokenCount; ++i) {
            uint256 tokenId = tokenMap[i];
            uint256 amount = amountMap[i];

            tokenIds[i] = tokenId;
            amounts[i] = amount;
            auctionTokens[tokenId] -= amount;
        }

        erc1155Contract.safeBatchTransferFrom(theBarn, auction.highestBidder, tokenIds, amounts, "");
    }

    function _resetERC721s(Auction storage auction) internal {
        address tokenAddress = auction.tokenAddress;
        uint256 tokenCount = auction.tokenCount;

        mapping(uint256 => uint256) storage tokenMap = auction.tokenIds;
        mapping(uint256 => bool) storage auctionTokens = auctionTokensERC721[tokenAddress];

        for (uint256 i; i < tokenCount; ++i) {
            uint256 tokenId = tokenMap[i];
            auctionTokens[tokenId] = false;
        }
    }

    function _resetERC1155s(Auction storage auction) internal {
        address tokenAddress = auction.tokenAddress;
        uint256 tokenCount = auction.tokenCount;
        uint256[] memory tokenIds = new uint256[](tokenCount);
        uint256[] memory amounts = new uint256[](tokenCount);

        mapping(uint256 => uint256) storage tokenMap = auction.tokenIds;
        mapping(uint256 => uint256) storage amountMap = auction.amounts;
        mapping(uint256 => uint256) storage auctionTokens = auctionTokensERC1155[tokenAddress];

        for (uint256 i; i < tokenCount; ++i) {
            uint256 tokenId = tokenMap[i];
            uint256 amount = amountMap[i];

            tokenIds[i] = tokenId;
            amounts[i] = amount;
            auctionTokens[tokenId] -= amount;
        }
    }

    function _checkAndResetERC721s(Auction storage auction) internal {
        address tokenAddress = auction.tokenAddress;
        uint256 tokenCount = auction.tokenCount;

        mapping(uint256 => uint256) storage tokenMap = auction.tokenIds;
        mapping(uint256 => bool) storage auctionTokens = auctionTokensERC721[tokenAddress];

        bool notRefundable = IERC721(tokenAddress).isApprovedForAll(theBarn, address(this));

        for (uint256 i; i < tokenCount; ++i) {
            uint256 tokenId = tokenMap[i];
            auctionTokens[tokenId] = false;

            notRefundable = notRefundable && (IERC721(tokenAddress).ownerOf(tokenId) == theBarn);
        }

        if (notRefundable) revert AuctionIsApproved();
    }

    function _checkAndResetERC1155s(Auction storage auction) internal {
        address tokenAddress = auction.tokenAddress;
        uint256 tokenCount = auction.tokenCount;
        uint256[] memory tokenIds = new uint256[](tokenCount);
        uint256[] memory amounts = new uint256[](tokenCount);

        mapping(uint256 => uint256) storage tokenMap = auction.tokenIds;
        mapping(uint256 => uint256) storage amountMap = auction.amounts;
        mapping(uint256 => uint256) storage auctionTokens = auctionTokensERC1155[tokenAddress];

        bool notRefundable = IERC1155(tokenAddress).isApprovedForAll(theBarn, address(this));

        for (uint256 i; i < tokenCount; ++i) {
            uint256 tokenId = tokenMap[i];
            uint256 amount = amountMap[i];

            tokenIds[i] = tokenId;
            amounts[i] = amount;
            auctionTokens[tokenId] -= amount;

            notRefundable = notRefundable && (IERC1155(tokenAddress).balanceOf(theBarn, tokenId) >= amount);
        }

        if (notRefundable) revert AuctionIsApproved();
    }

    function _distributeRewards(Auction storage auction) internal returns (uint256) {
        uint256 totalRewards;

        for (uint256 i; i < auction.bidderCount; ++i) {
            address bidder = auction.bidders[i];
            uint256 reward = auction.rewards[bidder];

            if (reward > 0) {
                unchecked {
                    balances[bidder] += reward;
                    totalRewards += reward;
                }
            }
        }

        return totalRewards;
    }
}
