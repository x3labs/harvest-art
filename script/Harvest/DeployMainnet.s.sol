// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../../src/Harvest.sol";

contract HarvestDeployMainnet is Script {
    Harvest harvest;

    function run() external {
        vm.startBroadcast();

        bytes32 salt = keccak256(abi.encodePacked(vm.envString("SALT_HARVEST")));

        harvest = new Harvest{salt: salt}(
            msg.sender,
            vm.envAddress("ADDRESS_BARN"),
            vm.envAddress("ADDRESS_CONTRACT_BID_TICKET")
        );

        vm.stopBroadcast();

        console.log("Harvest: ", address(harvest));
    }
}
