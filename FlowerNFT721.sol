// SPDX-License-Identifier: MIT

//deployed at rinkeby 0x08915522a235d5c906621a4ae60a7c360e8a599b

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract Flower is Ownable, ERC721URIStorage {

    constructor() ERC721("Flower", "FWR"){}

    function mint(address to, uint tokenId) public onlyOwner {
        _mint(to, tokenId);
    }

    function setTokenURI(uint256 tokenId, string memory _tokenURI) public onlyOwner {
        _setTokenURI(tokenId, _tokenURI);
    }
}
