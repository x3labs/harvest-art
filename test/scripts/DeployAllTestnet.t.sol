// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../../script/DeployAllTestnet.s.sol";

contract DeployAllTestnetTest is Test {
    DeployAllTestnet script;
    address public theBarn;
    address public user1;
    address public user2;

    function setUp() public {
        script = new DeployAllTestnet();
        theBarn = vm.addr(1);
        user1 = vm.addr(2);
        user2 = vm.addr(3);
    }

    function test_run() public {
        vm.setEnv("ADDRESS_BARN", vm.toString(theBarn));
        vm.setEnv("ADDRESS_TESTNET_WALLET_A", vm.toString(user1));
        vm.setEnv("ADDRESS_TESTNET_WALLET_B", vm.toString(user2));
        vm.setEnv("BID_TICKET_URI", "ipfs://QmfSM5YGibMFqTWe66GsGUKnyHte3HuXFUdr9aGZ55QPST");
        script.run();
    }
}
