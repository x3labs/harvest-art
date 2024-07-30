// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../../src/Auctions.sol";

contract AuctionsDeployMainnet is Script {
    Auctions auctions;

    function run() external {
        vm.startBroadcast();

        bytes32 salt = keccak256(abi.encodePacked(vm.envString("SALT_AUCTIONS")));

        auctions = new Auctions{salt: salt}(
            vm.envAddress("ADDRESS_DEPLOYER"),
            vm.envAddress("ADDRESS_BARN"),
            vm.envAddress("ADDRESS_CONTRACT_BID_TICKET")
        );

        vm.stopBroadcast();

        console.log("Auctions: ", address(auctions));
    }
}
