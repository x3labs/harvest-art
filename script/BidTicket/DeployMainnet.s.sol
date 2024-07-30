// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../../src/BidTicket.sol";

contract BidTicketDeployMainnet is Script {
    BidTicket bidTicket;

    function run() external {
        vm.startBroadcast();

        bytes32 salt = keccak256(abi.encodePacked(vm.envString("SALT_BID_TICKET")));
        
        bidTicket = new BidTicket{salt: salt}(tx.origin);

        bidTicket.setHarvestContract(vm.envAddress("ADDRESS_CONTRACT_HARVEST"));
        bidTicket.setAuctionsContract(vm.envAddress("ADDRESS_CONTRACT_AUCTIONS"));
        bidTicket.setURI(1, vm.envString("BID_TICKET_URI"));

        vm.stopBroadcast();

        console.log("BidTicket: ", address(bidTicket));
    }
}
