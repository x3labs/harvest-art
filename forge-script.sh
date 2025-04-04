#!/bin/bash

source .env.local

if [ -z "$ALCHEMY_API_KEY" ]; then
    echo "Missing ALCHEMY_API_KEY"
    exit 1
fi

anvil() {
    local script_name=$1
    local is_testnet=true
    local script=$(get_script $script_name $is_testnet)

    if [ -z "$script" ]; then
        echo "Unsupported script: $script_name"
        exit 1
    fi

    forge script $script \
        -vvvv \
        --fork-url http://localhost:8545 \
        --optimize \
        --optimizer-runs 10000 \
        --gas-estimate-multiplier 200 \
        --sender $ADDRESS_DEPLOYER \
        --interactives 1 \
        --broadcast
}

get_rpc_url() {
    local network=$1
    
    case $network in
        sepolia)
            echo -n "https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_API_KEY"
            ;;
        holesky)
            echo -n "https://eth-holesky.g.alchemy.com/v2/$ALCHEMY_API_KEY"
            ;;
        base-sepolia)
            echo -n "https://base-sepolia.g.alchemy.com/v2/$ALCHEMY_API_KEY"
            ;;
        amoy)
            echo -n "https://polygon-amoy.g.alchemy.com/v2/$ALCHEMY_API_KEY"
            ;;
        mainnet)
            echo -n "https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY"
            ;;
        polygon)
            echo -n "https://polygon-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY"
            ;;
        optimism)
            echo -n "https://opt-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY"
            ;;
        arbitrum)
            echo -n "https://arb-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY"
            ;;
        base)
            echo -n "https://base-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY"
            ;;
        zksync)
            echo -n "https://zksync-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY"
            ;;
        zksync-sepolia)
            echo -n "https://zksync-sepolia.g.alchemy.com/v2/$ALCHEMY_API_KEY"
            ;;
        blast)
            echo -n "https://blast-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY"
            ;;
        avalanche)
            echo -n "https://avax-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY"
            ;;
        apechain)
            echo -n "https://apechain-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY"
            ;;
        abstract)
            echo -n "https://abstract-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY"
            ;;
        *)
            echo -n ""
            ;;
    esac
}

get_script() {
    local script_name=$1
    local is_testnet=$2

    case $script_name in
        all)
            if [ "$is_testnet" = true ]; then
                echo -n "script/DeployAllTestnet.s.sol:DeployAll"
            else
                echo -n "script/DeployAll.s.sol:DeployAll"
            fi
            ;;
        harvest)
            echo -n "script/DeployHarvest.s.sol:Deploy"
            ;;
        auctions)
            if [ "$is_testnet" = true ]; then
                echo -n "script/DeployAuctionsTestnet.s.sol:DeployTestnet"
            else
                echo -n "script/DeployAuctions.s.sol:Deploy"
            fi
            ;;
        bidticket)
            if [ "$is_testnet" = true ]; then
                echo -n "script/DeployBidTicketTestnet.s.sol:DeployTestnet"
            else
                echo -n "script/DeployBidTicket.s.sol:Deploy"
            fi
            ;;
        dispenser)
            echo -n "script/DeployTicketDispenser.s.sol:Deploy"
            ;;
        mocks)
            echo -n "script/DeployMockTokens.s.sol:DeployMockTokens"
            ;;
        newdrop)
            echo -n "script/NewDrop.s.sol:NewDrop"
            ;;
        settings)
            echo -n "script/UpdateSettings.s.sol:UpdateSettings"
            ;;
        *)
            echo -n ""
            ;;
    esac
}

run_script() {
    local network=$1
    local script_name=$2

    local rpc_url=$(get_rpc_url $network)

    if [ -z "$rpc_url" ]; then
        echo "Unsupported network: $network"
        exit 1
    fi

    local is_testnet=false

    if [[ $network == "sepolia" || $network == "amoy" || $network == "mumbai" || $network == "holesky" || $network == "base-sepolia" ]]; then
        is_testnet=true
    fi

    local script=$(get_script $script_name $is_testnet)

    if [ -z "$script" ]; then
        echo "Unsupported script: $script_name"
        exit 1
    fi

    if [ -z "$ADDRESS_DEPLOYER" ]; then
        echo "Missing ADDRESS_DEPLOYER"
        exit 1
    fi

    forge script $script \
        -vvv \
        --rpc-url "$rpc_url" \
        --optimize \
        --optimizer-runs 100000 \
        --gas-estimate-multiplier 125 \
        --legacy \
        --retries 100 \
        --sender "$ADDRESS_DEPLOYER" \
        --interactives 1 \
        --broadcast
}

if [ $# -ne 2 ]; then
    echo "Usage: $0 <network> <script_name>"
    echo "Networks: anvil, sepolia, mainnet, polygon, optimism, arbitrum, base, base-sepolia, zksync"
    echo "Script names: all, harvest, auctions, bidticket, dispenser, mocks, newdrop, settings"
    exit 1
fi

network=$1
script_name=$2

case $network in
    anvil)
        anvil $script_name
        ;;
    *)
        run_script $network $script_name
        ;;
esac

exit 0