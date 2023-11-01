// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BidTicket.sol";
import "../src/Harvest.sol";
import "../src/Market.sol";

contract SetupSepoliaScript is Script {
    function setUp() public {}

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        BidTicket bidTicket = BidTicket(vm.envAddress("ADDRESS_BID_TICKET"));
        Harvest harvest = Harvest(payable(vm.envAddress("ADDRESS_HARVEST")));
        Market market = Market(vm.envAddress("ADDRESS_MARKET"));

        vm.startBroadcast(deployerPrivateKey);

        harvest.setBidTicketAddress(address(bidTicket));

        bidTicket.setHarvestContract(address(harvest));
        bidTicket.setMarketContract(address(market));

        bidTicket.mint(vm.envAddress("ADDRESS_TESTNET_WALLET_A"), 1, 100);
        bidTicket.mint(vm.envAddress("ADDRESS_TESTNET_WALLET_B"), 1, 100);

        market.setMinStartPrice(0.001 ether);
        market.setMinBidIncrement(0.001 ether);
        market.setAuctionDuration(15 minutes);

        vm.stopBroadcast();
    }
}
