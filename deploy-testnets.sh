#!/bin/bash

. .env.testnets

#########
# Anvil #
#########

anvil() {
    forge script script/DeployAllTestnet.s.sol:DeployAllTestnet \
        -vvvv \
        --fork-url http://localhost:8545 \
        --optimize \
        --optimizer-runs 10000 \
        --gas-estimate-multiplier 200 \
        --sender $DEPLOYER_ADDRESS \
        --interactives 1 \
        --broadcast
}

###########
# Sepolia #
###########

sepolia() {
    forge script script/DeployAllTestnet.s.sol:DeployAllTestnet \
        -vvv \
        --rpc-url $SEPOLIA_RPC_URL \
        --optimize \
        --optimizer-runs 10000 \
        --gas-estimate-multiplier 200 \
        --verify \
        --sender $DEPLOYER_ADDRESS \
        --interactives 1 \
        --broadcast
}

##########
# Goerli #
##########

goerli() {
    forge script script/DeployAllTestnet.s.sol:DeployAllTestnet \
        -vvv \
        --rpc-url $GOERLI_RPC_URL \
        --optimize \
        --optimizer-runs 10000 \
        --gas-estimate-multiplier 200 \
        --verify \
        --sender $DEPLOYER_ADDRESS \
        --interactives 1 \
        --broadcast
}

case $1 in
    anvil)
        anvil
        ;;
    sepolia)
        sepolia
        ;;
    goerli)
        goerli
        ;;
    *)
        echo "Usage: $0 {anvil|sepolia|goerli}"
        exit 1
esac

exit 0