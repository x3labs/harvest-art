// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../src/BidTicket.sol";

contract Deploy is Script {
    function run() external returns (address) {
        vm.startBroadcast();
        BidTicket bidTicket = new BidTicket(vm.envAddress("ADDRESS_DEPLOYER"));
        bidTicket.setHarvestContract(vm.envAddress("ADDRESS_CONTRACT_HARVEST"));
        bidTicket.setAuctionsContract(vm.envAddress("ADDRESS_CONTRACT_AUCTIONS"));
        bidTicket.setURI(1, vm.envString("BID_TICKET_URI"));
        vm.stopBroadcast();

        return address(bidTicket);
    }
}
