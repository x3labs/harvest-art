// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../test/lib/Mock721.sol";
import "../test/lib/Mock1155.sol";

contract DeployMockNFTsScript is Script {
    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        new Mock721();
        new Mock1155();

        vm.stopBroadcast();
    }
}
