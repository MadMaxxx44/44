// SPDX-License-Identifier: MIT

//deployed at goerli 0xe667152cccf241b1d491bdb76f4fa74a1589f07d

pragma solidity ^0.8.17;

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
