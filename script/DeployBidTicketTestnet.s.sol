// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../src/BidTicket.sol";
import "./DeployBidTicket.s.sol";

contract DeployTestnet is Script {
    function run() external returns (address) {
        address bidTicketAddress = new Deploy().run();
        
        BidTicket bidTicket = BidTicket(bidTicketAddress);

        vm.startBroadcast(vm.envAddress("ADDRESS_DEPLOYER"));
        bidTicket.mint(vm.envAddress("ADDRESS_TESTNET_WALLET_A"), 1, 100);
        bidTicket.mint(vm.envAddress("ADDRESS_TESTNET_WALLET_B"), 1, 100);
        vm.stopBroadcast();

        return bidTicketAddress;
    }
}
