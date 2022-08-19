// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MaximumToken is ERC20 ("MaximumToken", "MMT"), Ownable{
    constructor() {
        _mint(msg.sender, 10000 *10 ** 18);
    }

    function mint(address to, uint amount) external onlyOwner {
        _mint(to, amount);
    }
}