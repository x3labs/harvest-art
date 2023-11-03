// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../test/lib/Mock1155.sol";
import "../test/lib/Mock721.sol";
import "../src/Harvest.sol";
import "../src/Market.sol";
import "../src/BidTicket.sol";

contract DeployAllTestnet is Script {
    BidTicket bidTicket;
    Harvest harvest;
    Market market;

    function run() external {
        vm.startBroadcast();
        bidTicket = new BidTicket();
        harvest = new Harvest(vm.envAddress("ADDRESS_BARN"), address(bidTicket));
        market = new Market(vm.envAddress("ADDRESS_BARN"), address(bidTicket));

        console.log("BidTicket: ", address(bidTicket));
        console.log("Harvest: ", address(harvest));
        console.log("Market: ", address(market));

        bidTicket.setHarvestContract(address(harvest));
        bidTicket.setMarketContract(address(market));

        bidTicket.mint(vm.envAddress("ADDRESS_TESTNET_WALLET_A"), 1, 100);
        bidTicket.mint(vm.envAddress("ADDRESS_TESTNET_WALLET_B"), 1, 100);

        market.setMinStartPrice(0.001 ether);
        market.setMinBidIncrement(0.001 ether);
        market.setAuctionDuration(1 hours);
        vm.stopBroadcast();

        console.log("BidTicket Harvest: ", bidTicket.harvestContract());
        console.log("BidTicket Market: ", bidTicket.marketContract());
        console.log("Market MinStartPrice: ", market.minStartPrice());
        console.log("Market MinBidIncrement: ", market.minBidIncrement());
        console.log("Market AuctionDuration: ", market.auctionDuration());
    }
}
