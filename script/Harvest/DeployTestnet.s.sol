// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../../src/BidTicket.sol";
import "./Deploy.s.sol";

contract DeployTestnet is Script {
    function run() external returns (address) {
        return new Deploy().run();
    }
}
