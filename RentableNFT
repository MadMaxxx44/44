// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./ERC4907.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RentableNFT is ERC4907, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private tokenIds;

    constructor() ERC4907("RentableNFT", "RNFT") {}

    function mint(address to) public onlyOwner {
        tokenIds.increment();
        uint newTokenId = tokenIds.current();
        _safeMint(to, newTokenId);
    }

    function setTokenURI(uint256 tokenId, string memory _tokenURI) public {
        _setTokenURI(tokenId, _tokenURI);
    }
}
