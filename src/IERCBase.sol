// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERCBase {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function isApprovedForAll(address account, address operator) external view returns (bool);
}
