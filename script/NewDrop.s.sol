// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import "forge-std/Script.sol";
import "../src/TicketDispenser.sol";
import "../src/BidTicket.sol";

contract NewDrop is Script {
    function run() external {
        address dispenserAddress = vm.envAddress("ADDRESS_CONTRACT_DISPENSER");
        address bidTicketAddress = vm.envAddress("ADDRESS_CONTRACT_BID_TICKET");
        uint256 mintCount = vm.envUint("DROP_MINT_COUNT");
        uint256 tokenId = vm.envUint("DROP_TOKEN_ID");
        uint256 dropId = vm.envUint("DROP_ID");
        bytes32 merkleRoot = vm.envBytes32("DROP_MERKLE_ROOT");
        
        vm.startBroadcast();
        BidTicket bidTicket = BidTicket(bidTicketAddress);
        bidTicket.mint(dispenserAddress, tokenId, mintCount);

        TicketDispenser ticketDispenser = TicketDispenser(dispenserAddress);
        ticketDispenser.setMerkleRoot(dropId, merkleRoot);
        vm.stopBroadcast();
    }
}

