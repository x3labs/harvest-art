#!/bin/bash

source .env.local

if [ -z "$ALCHEMY_API_KEY" ]; then
    echo "Missing ALCHEMY_API_KEY"
    exit 1
fi

get_etherscan_api_key() {
    local network=$1
    case $network in
        polygon|amoy)
            echo -n "$POLYGONSCAN_API_KEY"
            ;;
        arbitrum)
            echo -n "$ARBISCAN_API_KEY"
            ;;
        base|base-sepolia)
            echo -n "$BASESCAN_API_KEY"
            ;;
        blast)
            echo -n "$BLAST_API_KEY"
            ;;
        optimism)
            echo -n "$OPTIMISM_API_KEY"
            ;;
        *)
            echo -n "$ETHERSCAN_API_KEY"
            ;;
    esac
}

get_chain_id() {
    local network=$1
    
    case $network in
        sepolia)
            echo -n "11155111"
            ;;
        holesky)
            echo -n "17000"
            ;;
        base-sepolia)
            echo -n "84532"
            ;;
        amoy)
            echo -n "80002"
            ;;
        mainnet)
            echo -n "1"
            ;;
        polygon)
            echo -n "137"
            ;;
        optimism)
            echo -n "10"
            ;;
        arbitrum)
            echo -n "42161"
            ;;
        base)
            echo -n "8453"
            ;;
        zksync)
            echo -n "324"
            ;;
        zksync-sepolia)
            echo -n "300"
            ;;
        blast)
            echo -n "81457"
            ;;
        avalanche)
            echo -n "43114"
            ;;
        *)
            echo -n ""
            ;;
    esac
}

verify_contract() {
    local network=$1
    local contract_address=$2
    local contract_path=$3
    local constructor_args=$4

    local chain_id=$(get_chain_id $network)

    if [ -z "$chain_id" ]; then
        echo "Unsupported network: $network"
        exit 1
    fi

    export ETHERSCAN_API_KEY=$(get_etherscan_api_key $network)

    forge verify-contract $contract_address \
        $contract_path --watch --chain-id $chain_id \
        --optimizer-runs 100000 \
        --constructor-args $constructor_args
}

verify_harvest() {
    local network=$1
    local address=$ADDRESS_CONTRACT_HARVEST
    local path="src/Harvest.sol:Harvest"
    local args=$(cast abi-encode "constructor(address,address,address,address)" \
        $ADDRESS_DEPLOYER $ADDRESS_BARN $ADDRESS_FARMER $ADDRESS_CONTRACT_BID_TICKET)
    verify_contract $network $address $path "$args"
}

verify_auctions() {
    local network=$1
    local address=$ADDRESS_CONTRACT_AUCTIONS
    local path="src/Auctions.sol:Auctions"
    local args=$(cast abi-encode "constructor(address,address,address,address)" \
        $ADDRESS_DEPLOYER $ADDRESS_BARN $ADDRESS_FARMER $ADDRESS_CONTRACT_BID_TICKET)
    verify_contract $network $address $path "$args"
}

verify_bidticket() {
    local network=$1
    local address=$ADDRESS_CONTRACT_BID_TICKET
    local path="src/BidTicket.sol:BidTicket"
    local args=$(cast abi-encode "constructor(address)" $ADDRESS_DEPLOYER)
    verify_contract $network $address $path "$args"
}

verify_dispenser() {
    local network=$1
    local address=$ADDRESS_CONTRACT_DISPENSER
    local path="src/TicketDispenser.sol:TicketDispenser"
    local args=$(cast abi-encode "constructor(address,address)" $ADDRESS_DEPLOYER $ADDRESS_CONTRACT_BID_TICKET)
    verify_contract $network $address $path "$args"
}

if [ $# -ne 2 ]; then
    echo "Usage: $0 <network> <contract>"
    echo "Networks: sepolia, mainnet, polygon, optimism, arbitrum, base, base-sepolia, zksync, etc."
    echo "Contracts: harvest, auctions, bidticket, dispenser"
    echo "Example: $0 sepolia harvest"
    exit 1
fi

network=$1
contract=$2

case $contract in
    harvest)
        verify_harvest $network
        ;;
    auctions)
        verify_auctions $network
        ;;
    bidticket)
        verify_bidticket $network
        ;;
    dispenser)
        verify_dispenser $network
        ;;
    *)
        echo "Unsupported contract: $contract"
        exit 1
        ;;
esac

# reset env vars
source .env.local

exit 0