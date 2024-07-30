// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../test/lib/Mock1155.sol";
import "../test/lib/Mock721.sol";
import "../src/Harvest.sol";
import "../src/Auctions.sol";
import "../src/BidTicket.sol";

contract DeployAllMainnet is Script {
    BidTicket bidTicket;
    Harvest harvest;
    Auctions auctions;

    function run() external {
        vm.startBroadcast();

        bytes32 salt;

        salt = keccak256(abi.encodePacked(vm.envString("SALT_BID_TICKET")));
        bidTicket = new BidTicket{salt: salt}(vm.envAddress("ADDRESS_DEPLOYER"));

        salt = keccak256(abi.encodePacked(vm.envString("SALT_HARVEST")));
        harvest = new Harvest{salt: salt}(
            vm.envAddress("ADDRESS_DEPLOYER"),
            vm.envAddress("ADDRESS_BARN"),
            address(bidTicket)
        );

        salt = keccak256(abi.encodePacked(vm.envString("SALT_AUCTIONS")));
        auctions = new Auctions{salt: salt}(
            vm.envAddress("ADDRESS_DEPLOYER"),
            vm.envAddress("ADDRESS_BARN"),
            address(bidTicket)
        );

        bidTicket.setHarvestContract(address(harvest));
        bidTicket.setAuctionsContract(address(auctions));
        bidTicket.setURI(1, vm.envString("BID_TICKET_URI"));

        vm.stopBroadcast();

        console.log("BidTicket: ", address(bidTicket));
        console.log("Harvest: ", address(harvest));
        console.log("Auctions: ", address(auctions));
    }
}
