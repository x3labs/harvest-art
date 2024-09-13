// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./IBidTicket.sol";

enum TokenType { ERC20, ERC721, ERC1155 }

interface IHarvest {
    event BatchTransfer(address indexed user, uint256 indexed totalTokens);

    error InsufficientBalance();
    error InvalidParamsLength();
    error InvalidTokenContract();
    error InvalidTokenContractLength();
    error InvalidTokenType();
    error MaxTokensPerTxReached();
    error TransferFailed();

    function batchTransfer(
        TokenType[] calldata types,
        address[] calldata contracts,
        uint256[] calldata tokenIds,
        uint256[] calldata counts
    ) external;

    function withdrawBalance() external;

    function bidTicket() external view returns (IBidTicket);
    function theBarn() external view returns (address);
    function salePrice() external view returns (uint256);
    function maxTokensPerTx() external view returns (uint256);
    function bidTicketTokenId() external view returns (uint256);
    function bidTicketMultiplier() external view returns (uint256);

    function setBarn(address _theBarn) external;
    function setBidTicketAddress(address bidTicket_) external;
    function setBidTicketMultiplier(uint256 multiplier) external;
    function setBidTicketTokenId(uint256 bidTicketTokenId_) external;
    function setMaxTokensPerTx(uint256 _maxTokensPerTx) external;
    function setSalePrice(uint256 _price) external;
}