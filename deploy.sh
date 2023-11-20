#!/bin/bash

. .env.local

if [ -z "$ALCHEMY_API_KEY" ]; then
    echo "Missing ALCHEMY_API_KEY"
    exit 1
fi

anvil() {
    forge script script/DeployAllTestnet.s.sol:DeployAllTestnet \
        -vvvv \
        --fork-url http://localhost:8545 \
        --optimize \
        --optimizer-runs 10000 \
        --gas-estimate-multiplier 200 \
        --sender $ADDRESS_DEPLOYER \
        --interactives 1 \
        --broadcast
}

testnet() {
    local rpcUrl=$1
    
    if [ -z "$rpcUrl" ]; then
        echo "Missing rpcUrl"
        exit 1
    fi

    if [ -z "$ADDRESS_DEPLOYER" ]; then
        echo "Missing ADDRESS_DEPLOYER"
        exit 1
    fi

    forge script script/DeployAllTestnet.s.sol:DeployAllTestnet \
        -vvvv \
        --rpc-url "$rpcUrl" \
        --optimize \
        --optimizer-runs 10000 \
        --gas-estimate-multiplier 200 \
        --verify \
        --sender "$ADDRESS_DEPLOYER" \
        --interactives 1 \
        --broadcast
}

mainnet() {
    local rpcUrl=$1

    if [ -z "$rpcUrl" ]; then
        echo "Missing rpcUrl"
        exit 1
    fi

    if [ -z "$ADDRESS_DEPLOYER" ]; then
        echo "Missing ADDRESS_DEPLOYER"
        exit 1
    fi

    forge script script/DeployAllMainnet.s.sol:DeployAllMainnet \
        -vvvv \
        --rpc-url "$rpcUrl" \
        --optimize \
        --optimizer-runs 10000 \
        --gas-estimate-multiplier 200 \
        --verify \
        --sender "$ADDRESS_DEPLOYER" \
        --interactives 1 \
        --broadcast
}

case $1 in
    anvil)
        anvil
        ;;
    sepolia)
        testnet https://eth-sepolia.g.alchemy.com/v2/$ALCHEMY_API_KEY
        ;;
    goerli)
        testnet https://eth-goerli.g.alchemy.com/v2/$ALCHEMY_API_KEY
        ;;
    mumbai)
        testnet https://polygon-mumbai.g.alchemy.com/v2/$ALCHEMY_API_KEY
        ;;
    mainnet)
        mainnet https://eth-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY
        ;;
    polygon)
        mainnet https://polygon-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY
        ;;
    optimism)
        mainnet https://opt-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY
        ;;
    arbitrum)
        mainnet https://arb-mainnet.g.alchemy.com/v2/$ALCHEMY_API_KEY
        ;;
    *)
        echo "Usage: $0 {anvil|sepolia|goerli|mumbai|mainnet|polygon|optimism|arbitrum}"
        exit 1
esac

exit 0