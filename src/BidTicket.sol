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
import "./IBidTicket.sol";

contract BidTicket is ERC1155P("BidTicket", "TCKT"), Ownable, IBidTicket {
    address public harvestContract;
    address public marketContract;

    error NotAuthorized();

    modifier onlyMinters() {
        if (msg.sender != harvestContract) {
            if (msg.sender != owner()) {
                revert NotAuthorized();
            }
        }
        _;
    }

    modifier onlyBurners() {
        if (msg.sender != marketContract) {
            if (msg.sender != owner()) {
                revert NotAuthorized();
            }
        }
        _;
    }

    constructor() {
        _initializeOwner(msg.sender);
    }

    function setURI(uint256 tokenId, string calldata tokenURI) external virtual onlyOwner {
        _setURI(tokenId, tokenURI);
    }

    function mint(address to, uint256 id, uint256 amount) external virtual onlyMinters {
        _mint(to, id, amount, "");
    }

    function mintBatch(address to, uint256[] calldata ids, uint256[] calldata amounts)
        public
        onlyMinters
    {
        _mintBatch(to, ids, amounts, "");
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
