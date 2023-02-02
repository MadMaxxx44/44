//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Escrow {

    address public nftAddress;
    uint256 public nftID;
    uint256 public purchasePrice;
    uint256 public escrowAmount;
    address payable public seller;
    address payable public buyer;

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Only buyer can call this method");
        _;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Only seller can call this method");
        _;
    }

    mapping(address => bool) public approval;

    constructor(address _nftAddress, uint256 _nftID, uint256 _purchasePrice, uint256 _escrowAmount, address payable _seller, address payable _buyer) {
        nftAddress = _nftAddress;
        nftID = _nftID;
        purchasePrice = _purchasePrice;
        escrowAmount = _escrowAmount;
        seller = _seller;
        buyer = _buyer;
    }

    function depositEarnest() public payable onlyBuyer {
        require(msg.value >= escrowAmount);
    }

    function approveSale() public {
        approval[msg.sender] = true;
    }

    function finalizeSale() public {
        require(approval[buyer]);
        require(approval[seller]);
        require(address(this).balance >= purchasePrice);

        (bool success, ) = payable(seller).call{value: address(this).balance}("");
        require(success);

        IERC721(nftAddress).transferFrom(seller, buyer, nftID);
    }

    receive() external payable {}

    function getBalance() public view returns (uint) {
        return address(this).balance;
    }
}
