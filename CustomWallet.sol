// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; 
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; 

contract PublicSale is Ownable, ReentrancyGuard {   
    using SafeERC20 for IERC20;
    IERC20 public tokenForSale; 
    uint public fee; 
    bool public onSale;
    
    event PrePaymentSent(address sender);
    event TokensSold(address buyer, uint amount); 
    event NextTokenSaleAboutToStart();

    struct SaleToken {
        uint tokenForSaleBalance;
        address seller;
        uint limit;  // define how many tokens can buy 1 user
        IERC20 tokenAddress; 
    }

    mapping(address => SaleToken) saleToken;
    mapping(address => uint) prePayments;
    mapping(address => IERC20) tokensForSale;

    address[] sellersQueoe; 

    constructor() {
        transferOwnership(msg.sender); 
    }

    fallback() external {}
    receive() external payable {}
    
    function queoe() public view returns(address[]memory) {
        return sellersQueoe; 
    }

    function tokenLimit() public view returns(uint) {
        return saleToken[sellersQueoe[0]].limit;
    }

    function currentTokenBalance() public view returns(uint) {
        return tokenForSale.balanceOf(address(this)); 
    }

    function setFee(uint _fee) public onlyOwner {
        fee = _fee; 
    }

    function sendPrepayment(IERC20 _feeToken, IERC20 _saleToken, uint _amount) public nonReentrant {
        require(_amount == fee, "incorrect prepayment");              
        IERC20(_feeToken).safeTransferFrom(msg.sender, owner(), _amount);         //user send prepayment contract add him in queoe
        sellersQueoe.push(msg.sender);                                            //then we match _saleToken with msg.sender
        tokensForSale[msg.sender] = _saleToken;                                   //and increase prepayment for msg.sender
        prePayments[msg.sender] = prePayments[msg.sender] + fee;                  
        emit PrePaymentSent(msg.sender);               
    }
    
    function putUpOnSale(IERC20 _token, uint _amount, uint _limit) public nonReentrant { 
        SaleToken storage token = saleToken[msg.sender];
        require(prePayments[msg.sender] > 0, "first you need to send prepayment");
        require(tokensForSale[msg.sender] == _token, "wrong token address");      //after seller can put his tokens on sale
        require(onSale != true, "try later");                                     //we check if he sent prepayment, and if he put on sale
        require(sellersQueoe[0] == msg.sender, "not your turn yet");              //token that he defined before in sendPrepayment function
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);      //check if now his turn to sale, transfer amount                     
        token.tokenForSaleBalance = token.tokenForSaleBalance + _amount;          //of his tokens and put contract onSale
        token.seller = msg.sender;                                                
        token.limit = _limit;                                                     
        token.tokenAddress = _token;                                              
        tokenForSale = _token;                                                     
        onSale = true;                                                             
    }
    
    function buyTokens(IERC20 _token, uint _amount) public nonReentrant {         
        SaleToken storage token = saleToken[sellersQueoe[0]];                      //users buy tokens for other tokens 1:1
        require(_amount <= token.limit, "use tokenLimit function");                //they transfer tokens directly to seller
        require(_token != tokenForSale, "incorrect token");                        //after smartcontract transfer sale tokens to msg.sender address
        IERC20(_token).safeTransferFrom(msg.sender, token.seller, _amount);        //if there is no tokens on balance, we remove seller from array, and put 
        IERC20(token.tokenAddress).safeTransfer(msg.sender, _amount);              //next seller on his place, after we clear info about sold tokens
        token.tokenForSaleBalance = token.tokenForSaleBalance - _amount;           //so next seller can put his tokens on sale            
        if (token.tokenForSaleBalance == 0){                                             
            tokenForSale = IERC20(0x0000000000000000000000000000000000000000);
            prePayments[token.seller] = prePayments[token.seller] - fee;
            onSale = false; 
            delete tokensForSale[token.seller];
            delete saleToken[sellersQueoe[0]];                                     
            _remove(sellersQueoe, 0);   
            emit NextTokenSaleAboutToStart(); 
        }
        else {
            emit TokensSold(msg.sender, _amount);                                  
        }
    }

    function _remove(address[]storage arr,uint _index) internal returns(address[]storage) {
        require(_index < arr.length, "index out of bound");
        for (uint i = _index; i < arr.length - 1; i++) {
            arr[i] = arr[i + 1];
        }
        arr.pop();
        return arr;
    }
}
