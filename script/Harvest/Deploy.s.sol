// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/console.sol";
import "forge-std/Script.sol";
import "../../src/Harvest.sol";
import "../Factory.s.sol";

contract Deploy is Factory {
    Harvest harvest;

    function run() external returns (address) {
        bytes memory initCode = abi.encodePacked(type(Harvest).creationCode);
        bytes memory args = abi.encode(
            vm.envAddress("ADDRESS_DEPLOYER"), 
            vm.envAddress("ADDRESS_BARN"), 
            vm.envAddress("ADDRESS_CONTRACT_BID_TICKET")
        );
        bytes32 salt = vm.envBytes32("SALT_HARVEST");

        return deploy("Harvest", initCode, salt, args);
    }
}
