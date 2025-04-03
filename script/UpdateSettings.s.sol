// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../src/Auctions.sol";
import "../src/Harvest.sol";

contract UpdateSettings is Script {
    Auctions auctions;
    Harvest harvest;

    function run() external {
        address auctionsAddress = vm.envAddress("ADDRESS_CONTRACT_AUCTIONS");
        address harvestAddress = vm.envAddress("ADDRESS_CONTRACT_HARVEST");

        vm.startBroadcast();
        auctions = Auctions(auctionsAddress);
        auctions.setMinStartingBid(0.01 ether);
        auctions.setAuctionDuration(1 days);
        auctions.setMaxTokens(10);

        harvest = Harvest(payable(harvestAddress));
        harvest.setBidTicketMultiplier(1);
        harvest.setServiceFee(0.005 ether);
        vm.stopBroadcast();
    }
}
