// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../../src/BidTicket.sol";
import "./Deploy.s.sol";

contract DeployTestnet is Script {
    BidTicket bidTicket;

    function run() external {
        new Deploy().run();
        
        bidTicket = BidTicket(vm.envAddress("ADDRESS_CONTRACT_BID_TICKET"));

        vm.startBroadcast();
        bidTicket.mint(vm.envAddress("ADDRESS_TESTNET_WALLET_A"), 1, 100);
        bidTicket.mint(vm.envAddress("ADDRESS_TESTNET_WALLET_B"), 1, 100);
        vm.stopBroadcast();
    }
}
