// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../src/TicketDispenser.sol";
import "./Factory.s.sol";

contract Deploy is Factory {
    TicketDispenser dispenser;

    function run() external returns (address) {
        bytes memory initCode = abi.encodePacked(type(TicketDispenser).creationCode);
        bytes memory args = abi.encode(
            vm.envAddress("ADDRESS_DEPLOYER"), 
            vm.envAddress("ADDRESS_CONTRACT_BID_TICKET")
        );
        bytes32 salt = vm.envBytes32("SALT_TICKET_DISPENSER");

        return deploy("TicketDispenser", initCode, salt, args);
    }
}
