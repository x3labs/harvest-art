// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../test/lib/Mock721.sol";
import "../test/lib/Mock1155.sol";

contract MintMockNFTsScript is Script {
    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        Mock721 mock721 = Mock721(vm.envAddress("ADDRESS_MOCK721"));
        Mock1155 mock1155 = Mock1155(vm.envAddress("ADDRESS_MOCK1155"));

        vm.startBroadcast(deployerPrivateKey);

        mock721.mint(vm.envAddress("ADDRESS_TESTNET_WALLET_A"), 10);
        mock721.mint(vm.envAddress("ADDRESS_TESTNET_WALLET_B"), 10);
        mock721.mint(vm.envAddress("ADDRESS_BARN"), 10);

        mock1155.mint(vm.envAddress("ADDRESS_TESTNET_WALLET_A"), 1, 10, "");
        mock1155.mint(vm.envAddress("ADDRESS_TESTNET_WALLET_B"), 1, 10, "");
        mock1155.mint(vm.envAddress("ADDRESS_BARN"), 1, 10, "");

        vm.stopBroadcast();
    }
}
