pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockFaultyERC20 is ERC20 {
    constructor() ERC20("MockToken", "MTK") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }

    function transferFrom(address, address, uint256) public  override returns (bool) {
        return true;
    }
}
