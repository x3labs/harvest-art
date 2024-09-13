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

    function batchTransfer(
        TokenType[] calldata types,
        address[] calldata contracts,
        uint256[] calldata tokenIds,
        uint256[] calldata counts
    ) external nonReentrant {
        uint256 length = contracts.length;

        require(length > 0, InvalidTokenContractLength());
        require(length == tokenIds.length && length == counts.length && length == types.length, InvalidParamsLength());

        BatchItem[] memory batchItems = new BatchItem[](length);
        uint256 totalTokens;

        address currentContract = contracts[0];
        require(currentContract != address(0), InvalidTokenContract());

        for (uint256 i; i < length; ++i) {
            if (contracts[i] != address(0)) {
                currentContract = contracts[i];
            }

            batchItems[i] = BatchItem(types[i], currentContract, tokenIds[i], counts[i]);

            unchecked {
                ++totalTokens;
            }
        }

        require(totalTokens <= maxTokensPerTx, MaxTokensPerTxReached());

        emit BatchTransfer(msg.sender, totalTokens);

        bidTicket.mint(msg.sender, bidTicketTokenId, totalTokens * bidTicketMultiplier);

        for (uint256 i; i < length; ++i) {
            if (batchItems[i].tokenType == TokenType.ERC20) {
                uint256 balance = IERC20(batchItems[i].contractAddress).balanceOf(msg.sender);
                require(balance > 0, InsufficientBalance());
                IERC20(batchItems[i].contractAddress).transferFrom(msg.sender, theBarn, balance);
            } else if (batchItems[i].tokenType == TokenType.ERC721) {
                IERC721(batchItems[i].contractAddress).transferFrom(msg.sender, theBarn, batchItems[i].tokenId);
            } else if (batchItems[i].tokenType == TokenType.ERC1155) {
                IERC1155(batchItems[i].contractAddress).safeTransferFrom(msg.sender, theBarn, batchItems[i].tokenId, batchItems[i].count, "");
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

    receive() external payable {}

    fallback() external payable {}
}