// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../../src/BidTicket.sol";
import "./Deploy.s.sol";

contract DeployTestnet is Script {
    function run() external {
        Harvest harvest = Harvest(new Deploy().run());
    }
}
