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
     * batchSale - Sell tokens from one or more contracts in a single transaction
     *
     * @param types The types of tokens to transfer.
     * @param contracts The addresses of the token contracts.
     * @param tokenIds The IDs of the tokens to transfer.
     * @param counts The counts of the tokens to transfer.
     *
     * Protip: for repeated contracts, use address(0) to save a little gas.
     */

    function batchSale(
        TokenType[] calldata types,
        address[] calldata contracts,
        uint256[] calldata tokenIds,
        uint256[] calldata counts,
        bool skipBidTicket
    ) external payable nonReentrant {
        uint256 totalTokens = types.length;
        uint256 totalSalePrice = salePrice * totalTokens;
        address currentContract;
        TokenType currentType;

        require(totalTokens > 0 
            && totalTokens == contracts.length 
            && totalTokens == tokenIds.length 
            && totalTokens == counts.length, 
            InvalidParamsLength());
        require(contracts[0] != address(0), InvalidTokenContract());
        require(totalTokens <= maxTokensPerTx, MaxTokensPerTxReached());
        require(msg.value >= serviceFee, InvalidServiceFee());

        emit Sale(msg.sender, totalSalePrice);

        if (!skipBidTicket) {
            bidTicket.mint(msg.sender, bidTicketTokenId, totalTokens * bidTicketMultiplier);
        }

        for (uint256 i; i < totalTokens; ++i) {
            currentType = types[i];

            if (contracts[i] != address(0)) {
                currentContract = contracts[i];
            }

            if (currentType == TokenType.ERC20) {    
                IERC20(currentContract).transferFrom(msg.sender, theBarn, counts[i]);
            } else if (currentType == TokenType.ERC721) {
                IERC721(currentContract).transferFrom(msg.sender, theBarn, tokenIds[i]);
            } else if (currentType == TokenType.ERC1155) {
                IERC1155(currentContract).safeTransferFrom(msg.sender, theBarn, tokenIds[i], counts[i], "");
            } else {
                revert InvalidTokenType();
            }
        }

        (bool paymentSuccess,) = payable(msg.sender).call{value: totalSalePrice}("");
        require(paymentSuccess, TransferFailed());

        if (msg.value > totalSalePrice) {
            (bool farmerSuccess,) = payable(theFarmer).call{value: msg.value - totalSalePrice}("");
            require(farmerSuccess, TransferFailed());
        }
    }

    /**
     * Owner-only functions
     */

    function setBarn(address theBarn_) external onlyOwner {
        theBarn = theBarn_;
    }

    function setFarmer(address theFarmer_) external onlyOwner {
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

    function setMaxTokensPerTx(uint256 maxTokensPerTx_) external onlyOwner {
        maxTokensPerTx = maxTokensPerTx_;
    }

    function setSalePrice(uint256 salePrice_) external onlyOwner {
        salePrice = salePrice_;
    }

    function setServiceFee(uint256 serviceFee_) external onlyOwner {
        serviceFee = serviceFee_;
    }

    /**
     * Emergency withdrawal functions just in case apes don't read
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