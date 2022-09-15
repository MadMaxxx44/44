// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; 
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; 

contract PublicSale is Ownable, ReentrancyGuard {   
    using SafeERC20 for IERC20; 
    uint public Fee; //how many % contract take from seller 
    event PrePaymentSent(address sender);
    event NewTokenAdded(IERC20 _tokenAddress);
    event TokensSold(address buyer, uint amount, IERC20 token); 

    struct Tokens {
        uint tokenBalance;
        address seller;
        uint limitForUser;
        IERC20 tokenAddress;
        mapping(address => uint) buyers; 
    }

    mapping(address => uint) prePayments;
    mapping(IERC20 => Tokens) public tokens;
     
    IERC20[] tokensOnSale;

    constructor() {
        transferOwnership(msg.sender); 
    }

    fallback() external {}
    receive() external payable {}

    function viewTokens() public view returns(IERC20[] memory) {
        return tokensOnSale;
    }
    //return current balance of tokens
    function currentTokenBalance(IERC20 _token) public view returns(uint) {
        return tokens[_token].tokenBalance; 
    }
    //return amount of tokens that msg.sender bought
    function buyerBalance(IERC20 _token) public view returns(uint) {
        return tokens[_token].buyers[msg.sender]; 
    }
    //return token limit for 1 user
    function tokenLimitForUser(IERC20 _token) public view returns(uint) {
        return tokens[_token].limitForUser; 
    }
    // _amount - how many tokens user want to sell 
    function calculatePrepayment(uint _howManyYouWantToSell) public view returns(uint) {
        return _howManyYouWantToSell*Fee/100; //contract take 10% of amount 
    }
    //owner can set fee that he want take from sellers
    function setFee(uint _fee) public onlyOwner {
        Fee = _fee; 
    }
    //send 10% of amount that user want to sell to owner as prepayment
    function sendPrepayment(IERC20 _token, uint _howManyYouWantToSell) public nonReentrant {
        IERC20(_token).safeTransferFrom(msg.sender, owner(), calculatePrepayment(_howManyYouWantToSell));
        prePayments[msg.sender] = prePayments[msg.sender] + calculatePrepayment(_howManyYouWantToSell); 
        emit PrePaymentSent(msg.sender);
    }
    
    function addToken(uint _tokenBalance, uint _limitForUser, IERC20 _tokenAddress) public nonReentrant {
        require(prePayments[msg.sender] == calculatePrepayment(_tokenBalance), "incorrect token balance"); 
        require(_limitForUser <= _tokenBalance, "incorrect limit"); 
        IERC20(_tokenAddress).safeTransferFrom(msg.sender, address(this), _tokenBalance); 
        Tokens storage token = tokens[_tokenAddress];
        token.tokenBalance = _tokenBalance;
        token.seller = msg.sender;
        token.limitForUser = _limitForUser;
        token.tokenAddress = _tokenAddress;
        prePayments[msg.sender] = 0;
        tokensOnSale.push(_tokenAddress);
        emit NewTokenAdded(_tokenAddress); 
    }

    function buy(IERC20 _tokenYouWantToBuy, IERC20 _tokenYouWantToSpend, uint _amount) public {
        Tokens storage token = tokens[_tokenYouWantToBuy];
        require(_amount <= token.limitForUser, "use tokenLimitForUser function");
        require(_tokenYouWantToBuy != _tokenYouWantToSpend, "incorrect token");
        IERC20(_tokenYouWantToSpend).safeTransferFrom(msg.sender, token.seller, _amount);
        IERC20(_tokenYouWantToBuy).safeTransfer(msg.sender, _amount);
        token.tokenBalance = token.tokenBalance - _amount;
        token.buyers[msg.sender] = token.buyers[msg.sender] + _amount;
        if (token.tokenBalance == 0) {
            _remove(_tokenYouWantToBuy);  
            delete tokens[_tokenYouWantToBuy];
            emit TokensSold(msg.sender, _amount, _tokenYouWantToBuy); 
        } 
        else {
            emit TokensSold(msg.sender, _amount, _tokenYouWantToBuy);
        }
    }

    function _remove(IERC20 _element) internal {
        if(tokensOnSale.length == 1) {
                tokensOnSale.pop(); 
            }
            else if (tokensOnSale[tokensOnSale.length - 1] == _element) {
                tokensOnSale.pop();
            }
            else {
                for (uint i = 0; i < tokensOnSale.length - 1; i++) {
                    if(_element == tokensOnSale[i]) {
                            tokensOnSale[i] = tokensOnSale[tokensOnSale.length - 1];
                            tokensOnSale.pop();
                }
            }
        }
    }
}
