// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

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