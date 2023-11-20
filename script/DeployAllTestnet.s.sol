// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
        bidTicket = new BidTicket();
        harvest = new Harvest(vm.envAddress("ADDRESS_BARN"), address(bidTicket));
        auctions = new Auctions(vm.envAddress("ADDRESS_BARN"), address(bidTicket));

        console.log("BidTicket: ", address(bidTicket));
        console.log("Harvest: ", address(harvest));
        console.log("Auctions: ", address(auctions));

        bidTicket.setHarvestContract(address(harvest));
        bidTicket.setAuctionsContract(address(auctions));

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
