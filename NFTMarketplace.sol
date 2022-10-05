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
    event SaleClosed(uint nonce);
    event TokenSold(uint nonce, uint amount);  

    struct NFTSale {
        address seller;
        address nftAddress;
        uint tokenId; 
        uint amount;
        uint price;
        Type tokenType;
        Status status;
    }

    mapping (uint => NFTSale) public tokens;
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

    function sellNFT(address _seller, address _nftAddress, uint _tokenId, uint _amount, uint _price, string calldata _tokenType) external nonReentrant {
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

    function buyNFT(uint _nonce, uint _amount) external nonReentrant {
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

    function closeSale(uint _nonce) external onlySellerOrOwner nonReentrant {
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
