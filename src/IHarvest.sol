// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "./IBidTicket.sol";

enum TokenType {
    ERC20,
    ERC721,
    ERC1155
}

interface IHarvest {
    event Sale(address indexed user, uint256 indexed salePrice);

    error DuplicateToken();
    error InsufficientBalance();
    error InvalidParamsLength();
    error InvalidServiceFee();
    error InvalidTokenContract();
    error InvalidTokenContractLength();
    error InvalidTokenType();
    error MaxTokensPerTxReached();
    error TransferFailed();
    error SalePriceTooHigh();
    error ServiceFeeTooLow();

    function batchSale(
        TokenType[] calldata types,
        address[] calldata contracts,
        uint256[] calldata tokenIds,
        uint256[] calldata counts,
        bool skipBidTicket
    ) external payable;

    function bidTicket() external view returns (IBidTicket);
    function theBarn() external view returns (address);
    function theFarmer() external view returns (address);
    function salePrice() external view returns (uint256);
    function serviceFee() external view returns (uint256);
    function maxTokensPerTx() external view returns (uint256);
    function bidTicketTokenId() external view returns (uint256);
    function bidTicketMultiplier() external view returns (uint256);

    function setBarn(address _theBarn) external;
    function setBidTicketAddress(address bidTicket_) external;
    function setBidTicketMultiplier(uint256 multiplier) external;
    function setBidTicketTokenId(uint256 bidTicketTokenId_) external;
    function setFarmer(address _theFarmer) external;
    function setMaxTokensPerTx(uint256 _maxTokensPerTx) external;
    function setSalePrice(uint256 _price) external;
    function setServiceFee(uint256 _serviceFee) external;

    function withdrawBalance() external;
    function withdrawERC20(address tokenAddress, uint256 amount) external;
}
