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
//  ______  Harvest.art v3 (BidTicket) _______

import "ERC1155P/contracts/ERC1155P.sol";
import "solady/src/auth/Ownable.sol";
import "../src/IBidTicket.sol";

contract BidTicket is ERC1155P("BidTicket", "TCKT"), Ownable, IBidTicket {
    address public harvestContract;
    address public marketContract;

    error NotAuthorized();

    modifier onlyMinters() {
        if (msg.sender != this.owner() && msg.sender != harvestContract) {
            revert NotAuthorized();
        }
        _;
    }

    modifier onlyBurners() {
        if (msg.sender != this.owner() && msg.sender != marketContract) {
            revert NotAuthorized();
        }
        _;
    }

    constructor() {
        _initializeOwner(msg.sender);
    }

    function setURI(uint256 tokenId, string calldata tokenURI) external virtual onlyOwner {
        _setURI(tokenId, tokenURI);
    }

    function mint(address to, uint256 id, uint256 amount, bytes memory data) external virtual onlyMinters {
        _mint(to, id, amount, data);
    }

    function mintBatch(address to, uint256[] calldata ids, uint256[] calldata amounts, bytes memory data)
        public
        onlyMinters
    {
        _mintBatch(to, ids, amounts, data);
    }

    function burn(address from, uint256 id, uint256 amount) external onlyBurners {
        _burn(from, id, amount);
    }

    function burnBatch(address from, uint256[] calldata ids, uint256[] calldata amounts) external onlyBurners {
        _burnBatch(from, ids, amounts);
    }

    function setHarvestContract(address harvestContract_) external onlyOwner {
        harvestContract = harvestContract_;
    }

    function setMarketContract(address marketContract_) external onlyOwner {
        marketContract = marketContract_;
    }
}
