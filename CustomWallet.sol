//SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol"; 
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./TransferHelper.sol";

contract CustomWallet is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;  

    event AllowanceChanged(address _spender, uint _amount);
    event MoneySent(address _receiver, uint _amount);
    event MoneyReceived(address _from, uint _amount);
    event NewToken(address _token);

    struct Token {
        address Address;
        uint balance; //balance of all tokens
        mapping (address => uint) balances;  //balance of tokens for certain address 
    }

    mapping(address => uint) public allowance; 
    mapping(address => Token) public tokens;

    fallback() external {}
    receive() external payable {
        emit MoneyReceived(msg.sender, msg.value);
    }

    function addToken(address _token) public onlyOwner {
        Token storage token = tokens[_token];
        token.Address = _token;
        token.balance = 0; 
        emit NewToken(_token);
    }

    function depositToken(address _token, uint _amount) public nonReentrant {
        Token storage token = tokens[_token];
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        token.balance = token.balance + _amount;
        token.balances[msg.sender] = token.balances[msg.sender] + _amount;
    }

    function withdraw(address _token, uint _amount) public nonReentrant {                
        Token storage token = tokens[_token];
        require(token.balances[msg.sender] >= _amount, "Not enough token balance");  //checks if user deposited tokens
        IERC20(_token).safeTransfer(msg.sender, _amount);
        token.balance = token.balance - _amount;
        token.balances[msg.sender] = token.balances[msg.sender] - _amount;
    }

    function withdrawEther(address payable _to, uint _amount) public nonReentrant ownerOrAllowed(_amount) {
        require(balanceOfEther() >= _amount, "Not enough money in contract");
        if (msg.sender != owner()) {  //decrease allowance for allowed users but not for owner
            decreaseAllowance(msg.sender, _amount);      
            TransferHelper.safeTransferETH(_to, _amount); //safely transfer ether
        }
        else {
            TransferHelper.safeTransferETH(_to, _amount);
        }
        emit MoneySent(_to, _amount);
    }

    function increaseAllowance(address _spender, uint256 _amount) public onlyOwner {
        allowance[_spender] = allowance[_spender] + _amount;
        emit AllowanceChanged(_spender, _amount);
    }

    function decreaseAllowance(address _spender, uint256 _amount) public ownerOrAllowed(_amount) {
        if (msg.sender == owner()) { //owner can decrease allowance for anyone 
            allowance[_spender] = allowance[_spender] - _amount;
            emit AllowanceChanged(_spender, _amount);
        }
        else {
            if(_spender == msg.sender) { //allowed user can decrease allowance only for himself 
                allowance[_spender] = allowance[_spender] - _amount;
                emit AllowanceChanged(_spender, _amount);
            }
            else {
                revert("You can not decrease somebody's allowance"); 
            }
        }
    }

    modifier ownerOrAllowed(uint _amount) {
        require(msg.sender == owner() || allowance[msg.sender] >= _amount, "You are not allowed");
        _;
    }
    
    //return total amount of token pool
    function tokenBalance(address _token) public view returns(uint) {
        return tokens[_token].balance;
    }

    //return total amount of deposited tokens for certain user
    function userBalance(address _token) public view returns(uint) {
        return tokens[_token].balances[msg.sender];
    }
    
    //return amount of all ether in contract
    function balanceOfEther() public view returns(uint) {
        return address(this).balance; 
    }

    function pause() private whenNotPaused{
        _pause();
    }
    function unpause() private whenPaused{
        _unpause();
    }
}
