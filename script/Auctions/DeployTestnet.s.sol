// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../../src/Auctions.sol";
import "./Deploy.s.sol";

contract DeployTestnet is Script {
    function run() external returns (address) {
        address auctionsAddress = new Deploy().run();
        Auctions auctions = Auctions(auctionsAddress);

        vm.startBroadcast(vm.envAddress("ADDRESS_DEPLOYER"));
        auctions.setMinStartingBid(0.001 ether);
        auctions.setMinBidIncrement(0.001 ether);
        auctions.setAuctionDuration(1 hours);
        vm.stopBroadcast();

        return auctionsAddress;
    }
}
