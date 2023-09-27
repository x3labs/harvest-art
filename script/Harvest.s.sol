// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Harvest.sol";

contract HarvestScript is Script {
    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new Harvest(vm.envAddress("ADDRESS_BID_TICKET"));

        vm.stopBroadcast();
    }
}
