//SPDX-License-Identifier: MIT

//deployed on goerli 0xcfac98fCC31925eb709a92ac99dFE7562af6B7BE

pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol"; 
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./TransferHelper.sol";

contract SimpleWallet is Ownable, ReentrancyGuard {
    event AllowanceChanged(address _spender, uint _amount);
    event MoneySent(address _receiver, uint _amount);
    event MoneyReceived(address _from, uint _amount);
    event NewToken(address _token);

    struct Token {
        address Address;
        uint balance; //balance of all tokens
        mapping (address => uint) balances;  //balance of tokens for certain address 
    }
 
    mapping(address => Token) public tokens;
    mapping(address => uint) public ethBalances; 

    fallback() external {}
    receive() external payable {
        ethBalances[msg.sender] += msg.value;
        emit MoneyReceived(msg.sender, msg.value);
    }

    modifier ownerOrClient(uint _amount) {
        require(msg.sender == owner() || ethBalances[msg.sender] >= _amount, "Not an owner or client");
        _;
    }
    //return total amount of deposited tokens for certain user
    function userBalance(address _token) public view returns(uint) {
        return tokens[_token].balances[msg.sender];
    }

    function viewTokenAddress(address _token) public view returns(address) {
        return tokens[_token].Address; 
    }

    function viewTokensBalance(address _token) public view returns(uint) {
        return tokens[_token].balance;
    }
    
    //return amount of all ether in contract
    function balanceOfEther() public view returns(uint) {
        return address(this).balance; 
    }

    function addToken(address _token) public onlyOwner {
        Token storage token = tokens[_token];
        token.Address = _token;
        emit NewToken(_token);
    }

    function depositToken(address _token, uint _amount) public {
        require(_amount > 0, "Can not deposit 0 tokens");
        Token storage token = tokens[_token];
        TransferHelper.safeTransferFrom(_token, msg.sender, address(this), _amount);
        token.balance = token.balance + _amount;
        token.balances[msg.sender] = token.balances[msg.sender] + _amount;
    }

    function depositEther() public payable {
        require(msg.value > 0, "msg.value can not be 0");
        ethBalances[msg.sender] += msg.value; 
    }

    function withdrawToken(address _token, uint _amount) public {                
        Token storage token = tokens[_token];
        require(_amount > 0, "Can not withdraw 0 tokens"); 
        require(token.balances[msg.sender] >= _amount, "Not enough token balance");  //checks if user deposited tokens
        TransferHelper.safeTransfer(_token, msg.sender, _amount);
        token.balance = token.balance - _amount;
        token.balances[msg.sender] = token.balances[msg.sender] - _amount;
    }

    function withdrawEther(address _to, uint _amount) public nonReentrant ownerOrClient(_amount) {
        require(balanceOfEther() >= _amount, "Not enough money in contract");
        require(_amount > 0, "can not withdraw 0");
        TransferHelper.safeTransferETH(_to, _amount); //safely transfer ether
        ethBalances[_to] -= _amount; 
        emit MoneySent(_to, _amount);
    }
}
