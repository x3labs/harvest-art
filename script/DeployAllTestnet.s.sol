// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../test/lib/Mock1155.sol";
import "../test/lib/Mock721.sol";
import "../src/Harvest.sol";
import "../src/Auctions.sol";
import "../src/BidTicket.sol";

contract DeployAllTestnet is Script {
    BidTicket bidTicket;
    Harvest harvest;
    Auctions auctions;

    function run() external {
        vm.startBroadcast();
        bytes32 salt;
        
        salt = keccak256(abi.encodePacked(vm.envString("SALT_BID_TICKET")));
        bidTicket = new BidTicket{salt: salt}(tx.origin);

        salt = keccak256(abi.encodePacked(vm.envString("SALT_HARVEST")));
        harvest = new Harvest{salt: salt}(tx.origin, vm.envAddress("ADDRESS_BARN"), address(bidTicket));

        salt = keccak256(abi.encodePacked(vm.envString("SALT_AUCTIONS")));
        auctions = new Auctions{salt: salt}(tx.origin, vm.envAddress("ADDRESS_BARN"), address(bidTicket));

        console.log("BidTicket: ", address(bidTicket));
        console.log("Harvest: ", address(harvest));
        console.log("Auctions: ", address(auctions));

        console.log("tx.origin: ", tx.origin);
        console.log("BidTicket Owner: ", bidTicket.owner());
        console.log("Harvest Owner: ", harvest.owner());
        console.log("Auctions Owner: ", auctions.owner());

        bidTicket.setHarvestContract(address(harvest));
        bidTicket.setAuctionsContract(address(auctions));
        bidTicket.setURI(1, vm.envString("BID_TICKET_URI"));

        bidTicket.mint(vm.envAddress("ADDRESS_TESTNET_WALLET_A"), 1, 100);
        bidTicket.mint(vm.envAddress("ADDRESS_TESTNET_WALLET_B"), 1, 100);

        auctions.setMinStartingBid(0.001 ether);
        auctions.setMinBidIncrement(0.001 ether);
        auctions.setAuctionDuration(1 hours);
        vm.stopBroadcast();

        console.log("BidTicket Harvest: ", bidTicket.harvestContract());
        console.log("BidTicket Auctions: ", bidTicket.auctionsContract());
        console.log("Auctions MinStartingBid: ", auctions.minStartingBid());
        console.log("Auctions MinBidIncrement: ", auctions.minBidIncrement());
        console.log("Auctions AuctionDuration: ", auctions.auctionDuration());
    }
}
