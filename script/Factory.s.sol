// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "forge-std/console.sol";
import "forge-std/console2.sol";
import "forge-std/Script.sol";

interface ImmutableCreate2Factory {
    function findCreate2Address( bytes32 salt, bytes calldata initCode) external view returns (address);
    function safeCreate2(bytes32 salt, bytes calldata initCode) external payable returns (address deploymentAddress);
}

contract Factory is Script {
    ImmutableCreate2Factory immutable factory = ImmutableCreate2Factory(0x0000000000FFe8B47B3e2130213B802212439497);

    function deploy(string memory friendlyName, bytes memory _initCode, bytes32 _salt, bytes memory _args) public returns (address) {
        require(_initCode.length > 0, InvalidInitCode());
        require(_salt != bytes32(0), InvalidSalt());

        bytes memory initCodeWithArgs = abi.encodePacked(_initCode, _args);
        address contractAddress = factory.findCreate2Address(_salt, initCodeWithArgs);

        console2.log(friendlyName, contractAddress);
        console2.log("--- init code hash for create2crunch ---");
        console2.logBytes32(keccak256(initCodeWithArgs));

        vm.broadcast();
        factory.safeCreate2(_salt, initCodeWithArgs);

        return contractAddress;
    }
}

error InvalidInitCode();
error InvalidSalt();