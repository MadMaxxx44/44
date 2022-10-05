// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol"; 
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./1155.sol"; //Dota2Collection
import "./721.sol"; //Flower721NFT

contract NFTMarketplace is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    enum Status {Sold, Listed}
    enum Type {ERC721, ERC1155}
    uint public nonce; 
    address public paymentToken;
    uint public fee;

    event TokenOnSale(uint nonce);
    event TokenSold(uint nonce, uint amount);
    event SaleClosed(uint nonce);
    event BatchTokensOnSale(uint nonce);  
    event BatchTokensSold(uint nonce); 
    event BatchSaleClosed(uint _nonce);

    struct NFTSale {
        address seller;
        address nftAddress;
        uint tokenId; 
        uint amount;
        uint price;
        Type tokenType;
        Status status;
    }

    struct BatchNFTSale {
        address seller;
        address nftAddress;
        uint[] tokenIds; 
        uint[] amounts;
        uint price;
        Type tokenType;
        Status status;
    }

    mapping (uint => NFTSale) public tokens;
    mapping (uint => BatchNFTSale) public batchTokens; 
    mapping (address => bool) public sellers; 

    constructor(address _paymentToken) {
        nonce = 1; //will count how many orders contract has
        paymentToken = _paymentToken;
        fee = 10;  
    }

    modifier onlySellerOrOwner() {
        require(msg.sender == owner() || sellers[msg.sender] == true, "only for sellers");
        _;
    }

    function viewBatchIds(uint _nonce) public view returns(uint[] memory) {
        return batchTokens[_nonce].tokenIds; 
    }

    function viewBatchAmounts(uint _nonce) public view returns(uint[] memory) {
        return batchTokens[_nonce].amounts; 
    }

    function sellSingleNFT(address _seller, address _nftAddress, uint _tokenId, uint _amount, uint _price, string calldata _tokenType) external nonReentrant {
        NFTSale storage token = tokens[nonce];
        token.seller = _seller;
        token.nftAddress = _nftAddress;
        token.tokenId = _tokenId;
        token.amount = _amount;
        token.price = _price;
        token.tokenType = _matchType(_tokenType);
        token.status = Status.Listed; 
        if (token.tokenType == Type.ERC721) {
            IERC721(_nftAddress).safeTransferFrom(msg.sender, address(this), _tokenId);
        }
        else if (token.tokenType == Type.ERC1155) {
            IERC1155(_nftAddress).safeTransferFrom(msg.sender, address(this), _tokenId, _amount, "");
        }
        else { revert("something went wrong"); }
        sellers[msg.sender] = true; 
        emit TokenOnSale(nonce);
        nonce++;
    }

    function buySingleNFT(uint _nonce, uint _amount) external nonReentrant {
        NFTSale storage token = tokens[_nonce];
        require(token.amount >= _amount, "incorrect token amount"); 
        IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), token.price * _amount);
        uint bounty = token.price * _amount - (((token.price * _amount)/100) * fee);
        IERC20(paymentToken).safeTransfer(token.seller, bounty);
        if (token.tokenType == Type.ERC721) {
            IERC721(token.nftAddress).safeTransferFrom(address(this), msg.sender, token.tokenId);
            sellers[token.seller] = false; 
            delete tokens[_nonce];
        }
        else if (token.tokenType == Type.ERC1155) {
            IERC1155(token.nftAddress).safeTransferFrom(address(this), msg.sender, token.tokenId, _amount, "");
            token.amount = token.amount - _amount;
            if (token.amount == 0) {
                sellers[token.seller] = false; 
                delete tokens[_nonce]; 
            }
        }
        else { revert("something went wrong"); }
        emit TokenSold(_nonce, _amount); 
    } 

    function closeSingleSale(uint _nonce) external onlySellerOrOwner nonReentrant {
        NFTSale storage token = tokens[_nonce];
        if (token.tokenType == Type.ERC721) {
            IERC721(token.nftAddress).safeTransferFrom(address(this), msg.sender, token.tokenId);
        }
        else if (token.tokenType == Type.ERC1155) {
            IERC1155(token.nftAddress).safeTransferFrom(address(this), msg.sender, token.tokenId, token.amount, "");
        }
        else { revert("something went wrong"); }
        sellers[token.seller] = false; 
        delete tokens[_nonce]; 
        emit SaleClosed(_nonce);
    }

    function sellBatchNFTs(address _seller, address _nftAddress, uint[] memory _tokenIds, uint[] memory _amounts, uint _price) external nonReentrant {
        BatchNFTSale storage token1155 = batchTokens[nonce];
        token1155.seller = _seller;
        token1155.nftAddress = _nftAddress;
        token1155.tokenIds = _tokenIds;
        token1155.amounts = _amounts;
        token1155.price = _price;
        token1155.tokenType = Type.ERC1155;
        token1155.status = Status.Listed;
        IERC1155(_nftAddress).safeBatchTransferFrom(msg.sender, address(this), _tokenIds, _amounts, "");
        sellers[msg.sender] = true;
        emit BatchTokensOnSale(nonce);
        nonce++; 
    }

    function buyBatchNFTs(uint _nonce) external nonReentrant {
        BatchNFTSale storage token1155 = batchTokens[_nonce];
        IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), _calculate1155amounts(_nonce)*token1155.price);
        uint bounty = token1155.price * _calculate1155amounts(_nonce) - (((_calculate1155amounts(_nonce)*token1155.price)/100) * fee); 
        IERC20(paymentToken).safeTransfer(token1155.seller, bounty);
        IERC1155(token1155.nftAddress).safeBatchTransferFrom(address(this), msg.sender, viewBatchIds(_nonce), viewBatchAmounts(_nonce), "");
        sellers[token1155.seller] = false;
        delete tokens[_nonce];
        emit BatchTokensSold(_nonce);
    }

    function closeBatchSale(uint _nonce) external onlySellerOrOwner nonReentrant {
        BatchNFTSale storage token1155 = batchTokens[_nonce];
        if (token1155.tokenType == Type.ERC1155) {
            IERC1155(token1155.nftAddress).safeBatchTransferFrom(address(this), msg.sender, viewBatchIds(_nonce), viewBatchAmounts(_nonce), "");
        }
        else { revert("something went wrong"); }
        sellers[token1155.seller] = false; 
        delete batchTokens[_nonce]; 
        emit BatchSaleClosed(_nonce);
    }

    function changePaymentToken(address _token) external onlyOwner {
        paymentToken = _token;
    }

    function setFee(uint _fee) public onlyOwner {
        fee = _fee; 
    }

    function _matchType(string memory _token)internal pure returns(Type) {
        if (keccak256(abi.encodePacked(_token)) == keccak256(abi.encodePacked("ERC721"))) {
            return Type.ERC721;
        }
        else if (keccak256(abi.encodePacked(_token)) == keccak256(abi.encodePacked("ERC1155"))) {
            return Type.ERC1155;
        }
        else{ revert("wrong name of token type"); }
    }

    function _calculate1155amounts(uint _nonce) internal view returns(uint) {
        uint result = 0; 
        for (uint i = 0; i < batchTokens[_nonce].amounts.length; i++) { 
            result = result + batchTokens[_nonce].amounts[i]; 
        }
        return result; 
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }
    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
    function onERC721Received(address, address, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    } 
}
