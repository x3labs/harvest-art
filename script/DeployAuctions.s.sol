// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../src/Auctions.sol";
import "./Factory.s.sol";

contract Deploy is Factory {
    Auctions auctions;

    function run() external returns (address) {
        bytes memory initCode = abi.encodePacked(type(Auctions).creationCode);
        bytes memory args = abi.encode(
            vm.envAddress("ADDRESS_DEPLOYER"), 
            vm.envAddress("ADDRESS_BARN"), 
            vm.envAddress("ADDRESS_CONTRACT_BID_TICKET")
        );
        bytes32 salt = vm.envBytes32("SALT_AUCTIONS");

        return deploy("Auctions", initCode, salt, args);
    }
}
