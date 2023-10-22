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
//  ____________  Harvest.art v3 _____________

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "solady/src/auth/Ownable.sol";
import "./IBidTicket.sol";

contract Harvest is Ownable {
    
    IBidTicket public bidTicket;

    address public theBarn;
    uint256 public defaultPrice = 1 gwei;
    uint256 public maxTokensPerTx = 100;
    uint256 public bidTicketTokenId = 1;

    mapping(address => uint256) private _contractPrices;

    error BarnNotSet();
    error InvalidTokenContractLength();
    error InvalidParamsLength();
    error MaxTokensPerTxReached();
    error TransferFailed();

    event BatchTransfer(address indexed user, uint256 indexed totalTokens);

    constructor(address bidTicket_) {
        _initializeOwner(msg.sender);
        bidTicket = IBidTicket(bidTicket_);
    }

    function batchTransfer(address[] calldata tokenContracts, uint256[] calldata tokenIds, uint256[] calldata counts)
        external
    {
        if (theBarn == address(0)) {
            revert BarnNotSet();
        }

        if (tokenContracts.length == 0) {
            revert InvalidTokenContractLength();
        }

        if (tokenContracts.length != tokenIds.length || tokenIds.length != counts.length) {
            revert InvalidParamsLength();
        }

        uint256 totalTokens;
        uint256 totalPrice;
        uint256 _defaultPrice = defaultPrice;

        for (uint256 i; i < tokenContracts.length;) {
            address tokenContract = tokenContracts[i];

            if (counts[i] == 0) {
                unchecked {
                    ++totalTokens;
                }

                totalPrice += _getPrice(_defaultPrice, tokenContract);
                IERC721(tokenContract).transferFrom(msg.sender, theBarn, tokenIds[i]);
            } else {
                totalTokens += counts[i];
                totalPrice += _getPrice(_defaultPrice, tokenContract) * counts[i];
                IERC1155(tokenContract).safeTransferFrom(msg.sender, theBarn, tokenIds[i], counts[i], "");
            }

            unchecked {
                ++i;
            }
        }

        if (totalTokens > maxTokensPerTx) {
            revert MaxTokensPerTxReached();
        }

        bidTicket.mint(msg.sender, bidTicketTokenId, totalTokens);

        (bool sent,) = payable(msg.sender).call{value: totalPrice}("");
        if (!sent) revert TransferFailed();

        emit BatchTransfer(msg.sender, totalTokens);
    }

    function _getPrice(uint256 _defaultPrice, address contractAddress) internal view returns (uint256) {
        if (_contractPrices[contractAddress] > 0) {
            return _contractPrices[contractAddress];
        } else {
            return _defaultPrice;
        }
    }

    function setBarn(address _theBarn) public onlyOwner {
        theBarn = _theBarn;
    }

    function setDefaultPrice(uint256 _defaultPrice) public onlyOwner {
        defaultPrice = _defaultPrice;
    }

    function setMaxTokensPerTx(uint256 _maxTokensPerTx) public onlyOwner {
        maxTokensPerTx = _maxTokensPerTx;
    }

    function setPriceByContract(address contractAddress, uint256 price) public onlyOwner {
        _contractPrices[contractAddress] = price;
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
