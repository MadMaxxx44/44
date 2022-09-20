//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract Dota2Collection is ERC1155, Ownable {

    uint public constant INVOKER = 0;
    uint public constant PUDGE = 1;
    uint public constant TINKER = 2;
    uint public constant SF = 3;
    uint public constant WEAVER_POMOYKA = 4; 

    constructor() ERC1155("https://bafybeif42xh7bmydacu3qdgnq2yc3icwy6ocdu7haiwl7ret42qb4ffre4.ipfs.nftstorage.link/{id}.json") {
    _mint(msg.sender, 0, 10, "");
    _mint(msg.sender, 1, 10, "");
    _mint(msg.sender, 2, 10, "");
    _mint(msg.sender, 3, 10, "");
    _mint(msg.sender, 4, 10, "");
    }
     
    function mint(address to, uint tokenId, uint amount, bytes memory data) public onlyOwner {
        _mint(to, tokenId, amount, data); 
    }

    function uri(uint tokenId) override public pure returns(string memory) {
        return(string(abi.encodePacked("https://bafybeif42xh7bmydacu3qdgnq2yc3icwy6ocdu7haiwl7ret42qb4ffre4.ipfs.nftstorage.link/", 
        Strings.toString(tokenId), ".json")));
    }
}
