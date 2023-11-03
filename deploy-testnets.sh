#!/bin/bash

# . .env.sepolia
# forge script script/DeployMockNFTs.s.sol:DeployMockNFTsScript --rpc-url $SEPOLIA_RPC_URL --optimize --optimizer-runs 10000 --broadcast --verify -vvvv
# forge script script/MintMockNFTs.s.sol:MintMockNFTsScript --rpc-url $SEPOLIA_RPC_URL --broadcast

forge script script/DeployTestnet.s.sol:DeployTestnet --fork-url http://localhost:8545 --broadcast --keystores LOCAL_TESTNET

# DON'T FORGET TO OPTIMIZE