// SPDX-License-Identifier: MIT

//deployed at goerli 0x7758Ec3b40D4debF3B86939Fcd10E473f47A0878

pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; 
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; 

contract PublicMultySale is Ownable, ReentrancyGuard {   
    using SafeERC20 for IERC20; 
    uint public Fee; //how many % contract take from seller 
    uint entryThreshold;//minimum tokens amount that users can sell
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
    mapping(IERC20 => bool) tokensForPrepayments;
     
    IERC20[] tokensOnSale;
    IERC20[] tokensForPrepayment;

    constructor() {
        transferOwnership(msg.sender); 
        Fee = 10; //for testing 
        entryThreshold = 50; //for testing
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
    //calculate sum that contract take from seller 
    function calculatePrepayment(uint _howManyYouWantToSell) public view returns(uint) {
        return _howManyYouWantToSell*Fee/100; //contract take 10% of amount 
    } 
    //users can check tokens for prepayment
    function viewTokensForPrepayment() public view returns(IERC20[] memory) {
        return tokensForPrepayment;
    }
    //owner can set fee that he want take from sellers
    function setFee(uint _fee) public onlyOwner {
        Fee = _fee; 
    }
    //owner set minimum amount of tokens that users can sell 
    function setThreshold(uint _entryThreshold) external onlyOwner {
        entryThreshold = _entryThreshold;
    }
    //owner can add tokens he want to get paid within prepayment
    function addTokenForPrepayment(IERC20 _token) external onlyOwner {
        tokensForPrepayments[_token] = true; 
        tokensForPrepayment.push(_token);  
    }
    
    function removeTokenForPrepayment(IERC20 _token) external onlyOwner {
        _remove(_token, tokensForPrepayment); 
    }
    //send 10% of amount that user want to sell to owner as prepayment
    function sendPrepayment(IERC20 _token, uint _howManyYouWantToSell) public nonReentrant {                 //first user send prepayment to owner 
        require(tokensForPrepayments[_token] == true, "check viewTokensForPrepayment");  
        require(_howManyYouWantToSell >= entryThreshold, "not enough amount of tokens"); 
        IERC20(_token).safeTransferFrom(msg.sender, owner(), calculatePrepayment(_howManyYouWantToSell));
        prePayments[msg.sender] = prePayments[msg.sender] + calculatePrepayment(_howManyYouWantToSell); 
        emit PrePaymentSent(msg.sender);
    }
    
    function addToken(uint _tokenBalance, uint _limitForUser, IERC20 _tokenAddress) public nonReentrant {    //after he can add token he wants to sell
        require(tokens[_tokenAddress].tokenBalance == 0, "token already on sale"); 
        require(prePayments[msg.sender] == calculatePrepayment(_tokenBalance), "incorrect token balance or you need to send prepayment");
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

    function buy(IERC20 _tokenYouWantToBuy, IERC20 _tokenYouWantToSpend, uint _amount) public {              //then other users can buy his tokens 
        Tokens storage token = tokens[_tokenYouWantToBuy];
        require(_amount <= token.limitForUser, "use tokenLimitForUser function");
        require(_tokenYouWantToBuy != _tokenYouWantToSpend, "incorrect token");
        IERC20(_tokenYouWantToSpend).safeTransferFrom(msg.sender, token.seller, _amount);
        IERC20(_tokenYouWantToBuy).safeTransfer(msg.sender, _amount);
        token.tokenBalance = token.tokenBalance - _amount;
        token.buyers[msg.sender] = token.buyers[msg.sender] + _amount;
        if (token.tokenBalance == 0) {
            _remove(_tokenYouWantToBuy, tokensOnSale);  
            delete tokens[_tokenYouWantToBuy];
        } 
        emit TokensSold(msg.sender, _amount, _tokenYouWantToBuy);
    }

    function _remove(IERC20 _element, IERC20[] storage arr) internal {
        if(arr.length == 1) {
                arr.pop(); 
            }
            else if (arr[arr.length - 1] == _element) {
                arr.pop();
            }
            else {
                for (uint i = 0; i < arr.length - 1; i++) {
                    if(_element == arr[i]) {
                        arr[i] = arr[arr.length - 1];
                        arr.pop();
                }
            }
        }
    }
}
