#!/bin/bash

. .env

forge script script/Deploy.s.sol:DeployScript --rpc-url $SEPOLIA_RPC_URL --optimize --optimizer-runs 10000 --broadcast --verify -vvvv
