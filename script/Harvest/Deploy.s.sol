// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

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
        bytes32 salt = 0x000000000000000000000000000000000000000069fc980fba66661405000090;

        return deploy("Harvest", initCode, salt, args);
    }
}
