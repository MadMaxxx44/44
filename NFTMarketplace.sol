// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol"; 
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol"; 
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract NFTMarketplace is Ownable {
    using SafeERC20 for IERC20;
    enum Status {Sold, Listed}
    enum Type {ERC721, ERC1155}
    uint public nonce; 
    address public paymentToken;
    uint public fee;
    address public marketOwner; 

    event NFT721TokenOnSale(uint nonce);
    event NFT721TokenSold(uint nonce);
    event NFT721SaleClosed(uint nonce);
    event NFT1155TokensOnSale(uint nonce);  
    event NFT1155TokensSold(uint nonce); 
    event NFT1155SaleClosed(uint _nonce);

    struct NFT721 {
        address seller;
        address nftAddress;
        uint tokenId; 
        uint price;
        Type tokenType;
        Status status;
    }

    struct NFT1155 {
        address seller;
        address nftAddress;
        uint[] tokenIds; 
        uint[] amounts;
        uint price;
        Type tokenType;
        Status status;
    }

    mapping (uint => NFT721) public NFTs721;
    mapping (uint => NFT1155) public NFTs1155;  

    constructor() {
        nonce = 1; //will count how many orders contract has
        fee = 10;  
        marketOwner = msg.sender;
    }

    function viewNFTs1155Ids(uint _nonce) public view returns(uint[] memory) {
        return NFTs1155[_nonce].tokenIds; 
    }

    function viewNFTs1155Amounts(uint _nonce) public view returns(uint[] memory) {
        return NFTs1155[_nonce].amounts; 
    }

    function viewMarketplaceTokenBalance() public view returns(uint) {
        return IERC20(paymentToken).balanceOf(address(this));
    }

    function sellNFT721(address _nftAddress, uint _tokenId, uint _price) external {
        NFT721 storage token = NFTs721[nonce];
        token.seller = msg.sender;
        token.nftAddress = _nftAddress;
        token.tokenId = _tokenId;
        token.price = _price;
        token.tokenType = Type.ERC721;
        token.status = Status.Listed; 
        IERC721(_nftAddress).safeTransferFrom(msg.sender, address(this), _tokenId);   
        emit NFT721TokenOnSale(nonce);
        nonce++;
    }

    function buyNFT721(uint _nonce) external {
        NFT721 storage token = NFTs721[_nonce]; 
        IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), token.price);
        uint bounty = token.price - (token.price * fee / 100);
        IERC20(paymentToken).safeTransfer(token.seller, bounty); 
        IERC721(token.nftAddress).safeTransferFrom(address(this), msg.sender, token.tokenId);
        delete NFTs721[_nonce];
        emit NFT721TokenSold(_nonce); 
    } 

    function closeNFT721Sale(uint _nonce) external {
        NFT721 storage token = NFTs721[_nonce];
        require(msg.sender == owner() || msg.sender == token.seller, "incorrect seller or owner");
        IERC721(token.nftAddress).safeTransferFrom(address(this), token.seller, token.tokenId);  
        delete NFTs721[_nonce]; 
        emit NFT721SaleClosed(_nonce);
    }

    function sell1155NFTs(address _nftAddress, uint[] memory _tokenIds, uint[] memory _amounts, uint _price) external {
        _check1155amounts(_amounts); 
        NFT1155 storage token1155 = NFTs1155[nonce];
        token1155.seller = msg.sender;
        token1155.nftAddress = _nftAddress;
        token1155.tokenIds = _tokenIds;
        token1155.amounts = _amounts;
        token1155.price = _price;
        token1155.tokenType = Type.ERC1155;
        token1155.status = Status.Listed;
        IERC1155(_nftAddress).safeBatchTransferFrom(msg.sender, address(this), _tokenIds, _amounts, "");
        emit NFT1155TokensOnSale(nonce);
        nonce++; 
    }

    function buy1155NFTs(uint _nonce) external {
        NFT1155 storage token1155 = NFTs1155[_nonce];
        IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), _calculate1155amounts(_nonce)*token1155.price);
        uint bounty = token1155.price * _calculate1155amounts(_nonce) - (((_calculate1155amounts(_nonce)*token1155.price)/100) * fee); 
        IERC20(paymentToken).safeTransfer(token1155.seller, bounty);
        IERC1155(token1155.nftAddress).safeBatchTransferFrom(address(this), msg.sender, viewNFTs1155Ids(_nonce), viewNFTs1155Amounts(_nonce), "");
        delete NFTs1155[_nonce];
        emit NFT1155TokensSold(_nonce);
    }

    function close1155Sale(uint _nonce) external {
        NFT1155 storage token1155 = NFTs1155[_nonce];
        require(msg.sender == owner() || msg.sender == token1155.seller, "incorrect seller or owner");
        IERC1155(token1155.nftAddress).safeBatchTransferFrom(address(this), token1155.seller, viewNFTs1155Ids(_nonce), viewNFTs1155Amounts(_nonce), ""); 
        delete NFTs1155[_nonce]; 
        emit NFT1155SaleClosed(_nonce);
    }

    function withdrawToken(address _address) public onlyOwner {
        IERC20(paymentToken).safeTransfer(_address, viewMarketplaceTokenBalance());
    }

    function withdrawEth() public onlyOwner {
        (bool success, ) = payable(marketOwner).call{value: address(this).balance}(""); 
        require(success);
    }

    function viewEthBalance() public view returns(uint) {
        return address(this).balance; 
    }

    function setPaymentToken(address _token) external onlyOwner {
        paymentToken = _token;
    }

    function setFee(uint _fee) external onlyOwner {
        fee = _fee; 
    }

    function _calculate1155amounts(uint _nonce) internal view returns(uint) {
        uint result = 0; 
        for (uint i = 0; i < NFTs1155[_nonce].amounts.length; i++) { 
            result = result + NFTs1155[_nonce].amounts[i]; 
        }
        return result; 
    }

    function _check1155amounts(uint[] memory arr) internal pure {
        for(uint i = 0; i < arr.length; i++) {
            if(arr[i] == 0) {
                revert("can not sell 0 tokens"); 
            }
        }
    }

    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
    function onERC721Received(address, address, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    } 

    receive() external payable {}
    fallback() external {}
}
