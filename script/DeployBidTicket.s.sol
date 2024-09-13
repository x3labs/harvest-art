// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../src/BidTicket.sol";
import "./Factory.s.sol";

contract Deploy is Factory {
    function run() external returns (address){
        bytes memory initCode = abi.encodePacked(type(BidTicket).creationCode);
        bytes memory args = abi.encode(vm.envAddress("ADDRESS_DEPLOYER"));
        bytes32 salt = vm.envBytes32("SALT_BID_TICKET");

        address bidTicketAddress = deploy("BidTicket", initCode, salt, args);
        
        vm.startBroadcast();
        BidTicket bidTicket = BidTicket(bidTicketAddress);
        bidTicket.setHarvestContract(vm.envAddress("ADDRESS_CONTRACT_HARVEST"));
        bidTicket.setAuctionsContract(vm.envAddress("ADDRESS_CONTRACT_AUCTIONS"));
        bidTicket.setURI(1, vm.envString("BID_TICKET_URI"));
        vm.stopBroadcast();

        return bidTicketAddress;
    }
}
