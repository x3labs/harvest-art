// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IAuctions {
    function startAuctionERC721(uint256 startingBid, address tokenAddress, uint256[] calldata tokenIds) external payable;
    function startAuctionERC1155(uint256 startingBid, address tokenAddress, uint256[] calldata tokenIds, uint256[] calldata amounts) external payable;
    function bid(uint256 auctionId, uint256 bidAmount) external payable;
    function claim(uint256 auctionId) external;
    function refund(uint256 auctionId) external;
    function abandon(uint256 auctionId) external;
    function withdraw() external;

    function getAuctionTokens(uint256 auctionId) external view returns (uint256[] memory, uint256[] memory);
    function getPendingRewards(address bidder, uint256[] calldata auctionIds) external view returns (uint256);
    function getClaimedAuctions(uint256 limit) external view returns (uint256[] memory);

    function setBarnAddress(address theBarn_) external;
    function setFarmerAddress(address theFarmer_) external;
    function setBidTicketAddress(address bidTicket_) external;
    function setBidTicketTokenId(uint256 bidTicketTokenId_) external;
    function setBidTicketCostStart(uint256 bidTicketCostStart_) external;
    function setBidTicketCostBid(uint256 bidTicketCostBid_) external;
    function setMaxTokens(uint256 maxTokens_) external;
    function setMinStartingBid(uint256 minStartingBid_) external;
    function setMinBidIncrement(uint256 minBidIncrement_) external;
    function setAuctionDuration(uint256 auctionDuration_) external;
    function setSettlementDuration(uint256 settlementDuration_) external;
    function setAntiSnipeDuration(uint256 antiSnipeDuration_) external;
    function setAbandonmentFeePercent(uint256 newFeePercent) external;
    function setOutbidRewardPercent(uint256 newPercent) external;

    event Abandoned(uint256 indexed auctionId, address indexed bidder, uint256 indexed fee);
    event Claimed(uint256 indexed auctionId, address indexed winner);
    event NewBid(uint256 indexed auctionId, address indexed bidder, uint256 indexed value);
    event Refunded(uint256 indexed auctionId, address indexed bidder, uint256 indexed value);
    event Started(address indexed bidder, address indexed tokenAddress, uint256[] indexed tokenIds);
    event Withdraw(address indexed user, uint256 indexed value);
    
    error AuctionActive();
    error AuctionEnded();
    error AuctionIsApproved();
    error AuctionNotEnded();
    error BidTooLow();
    error InvalidFeePercentage();
    error InvalidLengthOfAmounts();
    error InvalidLengthOfTokenIds();
    error InvalidStatus();
    error InvalidValue();
    error IsHighestBidder();
    error MaxTokensPerTxReached();
    error NoBalanceToWithdraw();
    error NoRewardsToClaim();
    error NotEnoughTokensInSupply();
    error NotHighestBidder();
    error SettlementPeriodNotExpired();
    error SettlementPeriodEnded();
    error StartPriceTooLow();
    error TokenAlreadyInAuction();
    error TokenNotOwned();
    error TransferFailed();
}
