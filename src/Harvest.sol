// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

//                            _.-^-._    .--.
//                         .-'   _   '-. |__|
//                        /     |_|     \|  |
//                       /               \  |
//                      /|     _____     |\ |
//                       |    |==|==|    |  |
//   |---|---|---|---|---|    |--|--|    |  |
//   |---|---|---|---|---|    |==|==|    |  |
//  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
//  ____________  Harvest.art v4 _____________

import "./IHarvest.sol";
import "solady/auth/Ownable.sol";
import "solady/utils/ReentrancyGuard.sol";

contract Harvest is IHarvest, Ownable, ReentrancyGuard {
    IBidTicket public bidTicket;
    address public theBarn;
    address public theFarmer;
    uint256 public salePrice = 1 gwei;
    uint256 public serviceFee = 0.001 ether;
    uint256 public maxTokensPerTx = 500;
    uint256 public bidTicketTokenId = 1;
    uint256 public bidTicketMultiplier = 1;

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
     * erc20Sale - Sell tokens from a single ERC-20 contract.
     *
     * @param contractAddress The address of the token contract.
     * @param amount The amount of tokens to transfer.
     *
     */

    function erc20Sale(
        address contractAddress,
        uint256 amount,
        bool skipBidTicket
    ) external payable nonReentrant {
        require(msg.value >= serviceFee, InvalidServiceFee());

        emit Sale(msg.sender, salePrice);

        if (!skipBidTicket) {
            bidTicket.mint(msg.sender, bidTicketTokenId, bidTicketMultiplier);
        }

        IERC20(contractAddress).transferFrom(msg.sender, theBarn, amount);

        (bool success,) = payable(msg.sender).call{value: salePrice}("");
        require(success, TransferFailed());

        _transferServiceFee(salePrice);
    }

    /** 
     * erc721Sale - Sell tokens from a single ERC-721 contract.
     *
     * @param contractAddress The address of the token contract.
     * @param tokenIds The IDs of the tokens to transfer.
     *
     */

    function erc721Sale(
        address contractAddress,
        uint256[] calldata tokenIds,
        bool skipBidTicket
    ) external payable nonReentrant {
        uint256 length = tokenIds.length;
        require(length > 0, InvalidParamsLength());
        require(length <= maxTokensPerTx, MaxTokensPerTxReached());
        require(msg.value >= serviceFee, InvalidServiceFee());

        uint256 totalSalePrice;
        unchecked {
            totalSalePrice = salePrice * length;
        }

        emit Sale(msg.sender, totalSalePrice);
        
        if (!skipBidTicket) {
            uint256 totalTickets;
            unchecked {
                totalTickets = length * bidTicketMultiplier;
            }

            bidTicket.mint(msg.sender, bidTicketTokenId, totalTickets);
        }

        for (uint256 i; i < length; ++i) {
            IERC721(contractAddress).transferFrom(msg.sender, theBarn, tokenIds[i]);
        }
        
        (bool success,) = payable(msg.sender).call{value: totalSalePrice}("");
        require(success, TransferFailed());

        _transferServiceFee(totalSalePrice);
    }

    /** 
     * erc1155Sale - Sell tokens from a single ERC-1155 contract.
     *
     * @param contractAddress The address of the token contract.
     * @param tokenIds The IDs of the tokens to transfer.
     * @param counts The counts of the tokens to transfer.
     *
     */

    function erc1155Sale(
        address contractAddress,
        uint256[] calldata tokenIds,
        uint256[] calldata counts,
        bool skipBidTicket
    ) external payable nonReentrant {
        uint256 length = tokenIds.length;
        require(length > 0 && length == counts.length, InvalidParamsLength());
        require(length <= maxTokensPerTx, MaxTokensPerTxReached());
        require(msg.value >= serviceFee, InvalidServiceFee());

        uint256 totalSalePrice;
        unchecked {
            totalSalePrice = salePrice * length;
        }

        emit Sale(msg.sender, totalSalePrice);
        
        if (!skipBidTicket) {
            uint256 totalTickets;
            unchecked {
                totalTickets = length * bidTicketMultiplier;
            }

            bidTicket.mint(msg.sender, bidTicketTokenId, totalTickets);
        }

        IERC1155(contractAddress).safeBatchTransferFrom(msg.sender, theBarn, tokenIds, counts, "");

        (bool success,) = payable(msg.sender).call{value: totalSalePrice}("");
        require(success, TransferFailed());

        _transferServiceFee(totalSalePrice);
    }

    /**
     * batchSale - Sell tokens from one or more contracts in a single transaction
     *
     * @param types The types of tokens to transfer.
     * @param contracts The addresses of the token contracts.
     * @param tokenIds The IDs of the tokens to transfer.
     * @param counts The counts of the tokens to transfer.
     *
     * Protip: for repeated contracts, use address(0) to save some gas (or use the other sale functions).
     */

    function batchSale(
        TokenType[] calldata types,
        address[] calldata contracts,
        uint256[] calldata tokenIds,
        uint256[] calldata counts,
        bool skipBidTicket
    ) external payable nonReentrant {
        uint256 totalTokens = types.length;
        require(totalTokens > 0 
            && totalTokens == contracts.length 
            && totalTokens == tokenIds.length 
            && totalTokens == counts.length, 
            InvalidParamsLength());
        require(totalTokens <= maxTokensPerTx, MaxTokensPerTxReached());
        require(msg.value >= serviceFee, InvalidServiceFee());

        address currentContract;
        TokenType currentType;

        for (uint256 i; i < totalTokens; ++i) {
            currentContract = contracts[i] == address(0) ? currentContract : contracts[i];
            require(currentContract != address(0), InvalidTokenContract());

            uint256 count = counts[i];
            currentType = types[i];

            if (currentType == TokenType.ERC20) {    
                IERC20(currentContract).transferFrom(msg.sender, theBarn, count);
            } else if (currentType == TokenType.ERC721) {
                IERC721(currentContract).transferFrom(msg.sender, theBarn, tokenIds[i]);
            } else if (currentType == TokenType.ERC1155) {
                IERC1155(currentContract).safeTransferFrom(msg.sender, theBarn, tokenIds[i], count, "");
            } else {
                revert InvalidTokenType();
            }
        }

        uint256 totalSalePrice;
        unchecked {
            totalSalePrice = salePrice * totalTokens;
        }

        emit Sale(msg.sender, totalSalePrice);
        
        if (!skipBidTicket) {
            uint256 totalTickets;
            unchecked {
                totalTickets = totalTokens * bidTicketMultiplier;
            }

            bidTicket.mint(msg.sender, bidTicketTokenId, totalTickets);
        }

        (bool success,) = payable(msg.sender).call{value: totalSalePrice}("");
        require(success, TransferFailed());

        _transferServiceFee(totalSalePrice);
    }

    function _transferServiceFee(uint256 totalSalePrice) private {
        uint256 serviceFee_ = msg.value >= totalSalePrice ? msg.value - totalSalePrice : 0;
        (bool success,) = payable(theFarmer).call{value: serviceFee_}("");
        require(success, TransferFailed());
    }

    /**
     * Owner-only functions
     */

    function setBarn(address theBarn_) public onlyOwner {
        theBarn = theBarn_;
    }

    function setFarmer(address theFarmer_) public onlyOwner {
        theFarmer = theFarmer_;
    }

    function setBidTicketAddress(address bidTicket_) external onlyOwner {
        bidTicket = IBidTicket(bidTicket_);
    }

    function setBidTicketMultiplier(uint256 bidTicketMultiplier_) external onlyOwner {
        bidTicketMultiplier = bidTicketMultiplier_;
    }

    function setBidTicketTokenId(uint256 bidTicketTokenId_) external onlyOwner {
        bidTicketTokenId = bidTicketTokenId_;
    }

    function setMaxTokensPerTx(uint256 maxTokensPerTx_) public onlyOwner {
        maxTokensPerTx = maxTokensPerTx_;
    }

    function setSalePrice(uint256 salePrice_) public onlyOwner {
        salePrice = salePrice_;
    }

    function setServiceFee(uint256 serviceFee_) public onlyOwner {
        serviceFee = serviceFee_;
    }

    /**
     * Emergency withdrawal functions just in case apes don't read (they don't)
     */

    function withdrawBalance() external onlyOwner {
        (bool success,) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, TransferFailed());
    }

    function withdrawERC20(address tokenAddress, uint256 amount) external onlyOwner {
        IERC20(tokenAddress).transfer(msg.sender, amount);
    }

    function withdrawERC721(address tokenAddress, uint256 tokenId, address to) external onlyOwner {
        IERC721(tokenAddress).safeTransferFrom(address(this), to, tokenId);
    }
    
    receive() external payable {}

    fallback() external payable {}
}