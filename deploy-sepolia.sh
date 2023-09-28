#!/bin/bash

. .env.sepolia

### Mock NFTs ###

# forge script script/DeployMockNFTs.s.sol:DeployMockNFTsScript --rpc-url $SEPOLIA_RPC_URL --optimize --optimizer-runs 10000 --broadcast --verify -vvvv
forge script script/MintMockNFTs.s.sol:MintMockNFTsScript --rpc-url $SEPOLIA_RPC_URL --broadcast
