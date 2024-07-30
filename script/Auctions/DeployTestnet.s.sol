// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../../src/Auctions.sol";

contract AuctionsDeployTestnet is Script {
    Auctions auctions;

    function run() external {
        vm.startBroadcast();

        bytes32 salt = keccak256(abi.encodePacked(vm.envString("SALT_AUCTIONS")));

        auctions = new Auctions{salt: salt}(
            vm.envAddress("ADDRESS_DEPLOYER"),
            vm.envAddress("ADDRESS_BARN"),
            vm.envAddress("ADDRESS_CONTRACT_BID_TICKET")
        );

        auctions.setMinStartingBid(0.001 ether);
        auctions.setMinBidIncrement(0.001 ether);
        auctions.setAuctionDuration(1 hours);

        vm.stopBroadcast();

        console.log("Auctions: ", address(auctions));
        console.log("Auctions MinStartingBid: ", auctions.minStartingBid());
        console.log("Auctions MinBidIncrement: ", auctions.minBidIncrement());
        console.log("Auctions AuctionDuration: ", auctions.auctionDuration());
    }
}
