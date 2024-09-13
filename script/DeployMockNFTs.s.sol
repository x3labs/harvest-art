// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/Script.sol";
import "../test/lib/Mock721.sol";
import "../test/lib/Mock1155.sol";

contract DeployMockNFTs is Script {
    Mock721 mock721;
    Mock1155 mock1155;

    function run() external {
        vm.startBroadcast();

        mock721 = new Mock721();
        mock721.mint(vm.envAddress("ADDRESS_TESTNET_WALLET_A"), 10);
        mock721.mint(vm.envAddress("ADDRESS_TESTNET_WALLET_B"), 10);
        mock721.mint(vm.envAddress("ADDRESS_BARN"), 10);

        mock1155 = new Mock1155();
        mock1155.mint(vm.envAddress("ADDRESS_TESTNET_WALLET_A"), 1, 10, "");
        mock1155.mint(vm.envAddress("ADDRESS_TESTNET_WALLET_B"), 1, 10, "");
        mock1155.mint(vm.envAddress("ADDRESS_BARN"), 1, 10, "");

        vm.stopBroadcast();
    }
}
