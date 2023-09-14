// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BidTicket.sol";
import "../src/HarvestArt.sol";
import "../src/HarvestMarket.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        BidTicket bidTicket = new BidTicket();
        HarvestArt harvestArt = new HarvestArt(address(bidTicket));
        HarvestMarket harvestMarket = new HarvestMarket(vm.envAddress("THE_BARN_ADDRESS"), address(bidTicket));

        bidTicket.setHarvestContract(address(harvestArt));
        bidTicket.setMarketContract(address(harvestMarket));

        vm.stopBroadcast();
    }
}
