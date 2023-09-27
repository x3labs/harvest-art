// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Market.sol";

contract MarketScript is Script {
    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new Market(vm.envAddress("ADDRESS_THE_BARN"), vm.envAddress("ADDRESS_BID_TICKET"));

        vm.stopBroadcast();
    }
}
