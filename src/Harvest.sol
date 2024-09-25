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
//  ____________  Harvest.art v4 _____________

import "./IHarvest.sol";
import "solady/auth/Ownable.sol";
import "solady/utils/ReentrancyGuard.sol";

contract Harvest is IHarvest, Ownable, ReentrancyGuard {
    struct BatchItem {
        TokenType tokenType;
        address contractAddress;
        uint256 tokenId;
        uint256 count;
    }

    IBidTicket public bidTicket;
    address public theBarn;
    uint256 public salePrice = 1 gwei;
    uint256 public maxTokensPerTx = 500;
    uint256 public bidTicketTokenId = 1;
    uint256 public bidTicketMultiplier = 1;

    mapping(address => uint256) public tokenIdToMultiplier;

    constructor(address owner_, address theBarn_, address bidTicket_) {
        _initializeOwner(owner_);
        theBarn = theBarn_;
        bidTicket = IBidTicket(bidTicket_);
    }

    /**
     * batchTransfer - Sell multiple tokens in a single transaction
     *
     * @param types The types of tokens to transfer.
     * @param contracts The addresses of the token contracts.
     * @param tokenIds The IDs of the tokens to transfer.
     * @param counts The counts of the tokens to transfer.
     *
     * @dev tip: for repeated contracts, use address(0) to save some gas
     */

    function batchTransfer(
        TokenType[] calldata types,
        address[] calldata contracts,
        uint256[] calldata tokenIds,
        uint256[] calldata counts
    ) external nonReentrant {
        uint256 totalTokens;
        uint256 length = contracts.length;
        require(length > 0, InvalidTokenContractLength());
        require(length == tokenIds.length && length == counts.length && length == types.length, InvalidParamsLength());

        address currentContract = contracts[0];
        require(currentContract != address(0), InvalidTokenContract());

        BatchItem[] memory batchItems = new BatchItem[](length);
        uint256 batchItemsCount;

        for (uint256 i; i < length; ++i) {
            if (contracts[i] != address(0)) {
                currentContract = contracts[i];
            }

            bool isFound;

            for (uint256 j; j < batchItemsCount; ++j) {
                if (batchItems[j].contractAddress == currentContract) {
                    TokenType tokenType = types[i];

                    if (tokenType == TokenType.ERC20
                    || (tokenType == TokenType.ERC1155 && batchItems[j].tokenId == tokenIds[i])) {
                        batchItems[j].count += counts[i];
                        isFound = true;
                        break;
                    }
                }
            }

            if (!isFound) {
                batchItems[batchItemsCount] = BatchItem(types[i], currentContract, tokenIds[i], counts[i]);
                unchecked {
                    ++batchItemsCount;
                    ++totalTokens;
                }
            }
        }

        require(totalTokens <= maxTokensPerTx, MaxTokensPerTxReached());

        emit BatchTransfer(msg.sender, totalTokens);
        bidTicket.mint(msg.sender, bidTicketTokenId, totalTokens * bidTicketMultiplier);

        for (uint256 i; i < batchItemsCount; ++i) {
            BatchItem memory item = batchItems[i];
            if (item.tokenType == TokenType.ERC20) {    
                IERC20(item.contractAddress).transferFrom(msg.sender, theBarn, item.count);
            } else if (item.tokenType == TokenType.ERC721) {
                IERC721(item.contractAddress).transferFrom(msg.sender, theBarn, item.tokenId);
            } else if (item.tokenType == TokenType.ERC1155) {
                IERC1155(item.contractAddress).safeTransferFrom(msg.sender, theBarn, item.tokenId, item.count, "");
            } else {
                revert InvalidTokenType();
            }
        }

        (bool success,) = payable(msg.sender).call{value: salePrice * totalTokens}("");
        require(success, TransferFailed());
    }

    function setBarn(address theBarn_) public onlyOwner {
        theBarn = theBarn_;
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

    function withdrawBalance() external onlyOwner {
        (bool success,) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, TransferFailed());
    }

    function withdrawERC20(address tokenAddress, uint256 amount) external onlyOwner {
        IERC20(tokenAddress).transfer(msg.sender, amount);
    }

    receive() external payable {}

    fallback() external payable {}
}