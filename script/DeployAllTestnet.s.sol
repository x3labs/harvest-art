// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import {DeployTestnet as DeployBidTicket} from "./BidTicket/DeployTestnet.s.sol";
import {DeployTestnet as DeployHarvest} from "./Harvest/DeployTestnet.s.sol";
import {DeployTestnet as DeployAuctions} from "./Auctions/DeployTestnet.s.sol";

contract DeployAll is Script {
    function run() external {
        address bidTicketAddress = new DeployBidTicket().run();
        address harvestAddress = new DeployHarvest().run();
        address auctionsAddress = new DeployAuctions().run();

        console.log("BidTicket Address: %s", bidTicketAddress);
        console.log("Harvest Address: %s", harvestAddress);
        console.log("Auctions Address: %s", auctionsAddress);
    }
}
