// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../../src/Harvest.sol";

contract HarvestDeployTestnet is Script {
    Harvest harvest;

    function run() external {
        vm.startBroadcast();
        
        bytes32 salt = keccak256(abi.encodePacked(vm.envString("SALT_HARVEST")));

        harvest = new Harvest{salt: salt}(
            vm.envAddress("ADDRESS_DEPLOYER"),
            vm.envAddress("ADDRESS_BARN"),
            vm.envAddress("ADDRESS_CONTRACT_BID_TICKET")
        );

        vm.stopBroadcast();

        console.log("Harvest: ", address(harvest));
    }
}
