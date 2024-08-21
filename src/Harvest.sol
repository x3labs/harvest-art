// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

//                            _.-^-._    .--.
//                         .-'   _   '-. |__|
//                        /     |_|     \|  |
//                       /               \  |
//                      /|     _____     |\ |
//                       |    |==|==|    |  |
//   |---|---|---|---|---|    |--|--|    |  |
//   |---|---|---|---|---|    |==|==|    |  |
//  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
//  ____________  Harvest.art v3.1 _____________

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "solady/src/auth/Ownable.sol";
import "./IBidTicket.sol";

enum TokenType { ERC20, ERC721, ERC1155 }

contract Harvest is Ownable {
    IBidTicket public bidTicket;
    address public theBarn;
    uint256 public price = 1 gwei;
    uint256 public maxTokensPerTx = 500;
    uint256 public bidTicketTokenId = 1;

    error InvalidParamsLength();
    error InvalidTokenContractLength();
    error InvalidTokenType();
    error MaxTokensPerTxReached();
    error TransferFailed();
    
    event BatchTransfer(address indexed user, uint256 indexed totalTokens);

    constructor(address owner_, address theBarn_, address bidTicket_) {
        _initializeOwner(owner_);
        theBarn = theBarn_;
        bidTicket = IBidTicket(bidTicket_);
    }

    //@audit No check of the contract addresses
    function batchTransfer(
        TokenType[] calldata types,
        address[] calldata contracts,
        uint256[] calldata tokenIds,
        uint256[] calldata counts
    ) external {
        uint256 length = contracts.length;

        if (length == 0) {
            revert InvalidTokenContractLength();
        }

        if (length != tokenIds.length || length != counts.length || length != types.length) {
            revert InvalidParamsLength();
        }

        uint256 totalTokens;
        uint256 totalPrice;
        address currentContract = contracts[0];

        for (uint256 i; i < length; ++i) {
            TokenType tokenType = types[i];
            //@audit This doesn't look good
            address tokenContract = contracts[i] == address(0) ? currentContract : contracts[i];
            currentContract = tokenContract;

            if (tokenType == TokenType.ERC20) {
                unchecked {
                    ++totalTokens;
                    totalPrice += price;
                }
                bool success = IERC20(tokenContract).transferFrom(msg.sender, theBarn, counts[i]);
                if (!success) revert TransferFailed();
            } else if (tokenType == TokenType.ERC721) {
                unchecked {
                    ++totalTokens;
                    totalPrice += price;
                }
                //@audit Doesn't check if the barn contract can accept the tokens or not
                IERC721(tokenContract).transferFrom(msg.sender, theBarn, tokenIds[i]);
            } else if (tokenType == TokenType.ERC1155) {
                //@audit Will it revert for 0?
                uint256 count = counts[i];
                unchecked {
                    totalTokens += count;
                    totalPrice += price * count;
                }
                IERC1155(tokenContract).safeTransferFrom(msg.sender, theBarn, tokenIds[i], count, "");
            } else {
                revert InvalidTokenType();
            }
        }

        if (totalTokens > maxTokensPerTx) {
            revert MaxTokensPerTxReached();
        }

        bidTicket.mint(msg.sender, bidTicketTokenId, totalTokens);

        emit BatchTransfer(msg.sender, totalTokens);

        (bool sent,) = payable(msg.sender).call{value: totalPrice}("");
        if (!sent) revert TransferFailed();
    }

    function setBarn(address _theBarn) public onlyOwner {
        theBarn = _theBarn;
    }

    function setPrice(uint256 _price) public onlyOwner {
        price = _price;
    }

    function setMaxTokensPerTx(uint256 _maxTokensPerTx) public onlyOwner {
        maxTokensPerTx = _maxTokensPerTx;
    }

    function setBidTicketAddress(address bidTicket_) external onlyOwner {
        bidTicket = IBidTicket(bidTicket_);
    }

    function setBidTicketTokenId(uint256 bidTicketTokenId_) external onlyOwner {
        bidTicketTokenId = bidTicketTokenId_;
    }

    function withdrawBalance() external onlyOwner {
        (bool success,) = payable(msg.sender).call{value: address(this).balance}("");
        if (!success) revert TransferFailed();
    }

    receive() external payable {}

    fallback() external payable {}
}