// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";                       
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; 
import "@openzeppelin/contracts/access/Ownable.sol";

contract Staking is Ownable, ReentrancyGuard {         
    using SafeERC20 for IERC20;            
    uint public totalUsers;  
    uint public periodsCount; 

    event NewStaker(uint _amount, uint _period);
    event TokenChanged(IERC20 _token);
    event RewardClaimed(uint result);
    event NewPoolCreated(IERC20 _token, uint _priceToStart);
    event TokenGranted(IERC20 _token, uint _amount); 
    
    struct PoolInfo {
        IERC20 token;   //token address          
        uint priceToStart;
        uint poolBalance;
        uint poolLimit;
        uint poolGrant;  //token got to be granted, so users can unstake their tokens
        uint userLimit; //how many tokens can stake 1 user
    }

    struct UserInfo {
        uint amount; //how many tokens user stake
        uint timeStart;
        uint period;
    }

    struct PeriodInfo {
        uint periodNumber;
        uint periodTime;
        uint percentReward;
    }
  
    mapping(IERC20 => mapping(address => UserInfo)) public users;
    mapping(IERC20 => PoolInfo) public pools;
    mapping(uint => PeriodInfo) public periods;

    constructor() {}

    fallback() external {}
    receive() external payable {}
 
    // calculate passed time of staking for user
    function calculatePassedTime(IERC20 _token) public view returns(uint timePassed) {
        UserInfo storage user = users[_token][msg.sender];
        require(user.amount > 0, "You do not have staked assets");
        return block.timestamp - user.timeStart;
    }
    
    function calculateReward(IERC20 _token, uint _period, uint _amount) public view returns(uint reward) {
        UserInfo storage user = users[_token][msg.sender];
        require(_period <= periodsCount && _period != 0, "incorrect period");
        if(user.amount == 0) { //for users that dont have staked tokens now, but want to calculate possible reward
            return _amount*periods[_period].percentReward / 100; 
        }
        else { //calculate reward for stakers
            return _amount*periods[user.period].percentReward / 100;
        }
    }

    function selfDestruct(address payable _owner) public onlyOwner{
        selfdestruct(_owner);
    }

    function addPeriods(uint _periodNumber, uint _periodTime, uint _percentReward) public onlyOwner {
        require(_periodNumber != 0, "incorrect period number"); 
        PeriodInfo storage period = periods[_periodNumber];
        period.periodNumber = _periodNumber;
        period.periodTime = _periodTime;
        period.percentReward = _percentReward; 
        periodsCount++;
    }

    function delPeriod(uint _numberOfPeriod) public onlyOwner {
        delete periods[_numberOfPeriod];
        periodsCount--; 
    }

    function grantToken(IERC20 _token, uint _amount) public {
        PoolInfo storage pool = pools[_token];
        IERC20(pool.token).safeTransferFrom(msg.sender, address(this), _amount); 
        pool.poolGrant = pool.poolGrant + _amount; 
        emit TokenGranted(_token, _amount); 
    }

    function poolInstance(IERC20 _token, uint _priceToStart, uint _poolLimit, uint _userLimit) public onlyOwner{
        PoolInfo storage pool = pools[_token];
        pool.token = _token;
        pool.priceToStart = _priceToStart;
        pool.poolLimit = _poolLimit;
        pool.userLimit = _userLimit;
        emit NewPoolCreated(_token, _priceToStart);
    }
    
    function stake(uint _amount, IERC20 _token, uint _periodNumber) public nonReentrant {
        PoolInfo storage pool = pools[_token];
        UserInfo storage user = users[_token][msg.sender];
        require(_periodNumber <= periodsCount && _periodNumber != 0, "incorrect period");
        require(_amount >= pool.priceToStart, "Not enough amount to start");
        require(pool.poolBalance != pool.poolLimit, "tokens sold out");
        require(pool.poolBalance + _amount <= pool.poolLimit, "try to reduce amount");
        require(_amount <= pool.userLimit, "amount exceeds limit for user"); 
        IERC20(pool.token).safeTransferFrom(msg.sender, address(this), _amount);
        user.amount = _amount;
        user.timeStart = block.timestamp;
        user.period = periods[_periodNumber].periodNumber; 
        pool.poolBalance = pool.poolBalance + _amount;
        totalUsers++;
        emit NewStaker(_amount, _periodNumber);
    }

    function unstake(IERC20 _token) public nonReentrant {
        PoolInfo storage pool = pools[_token];
        UserInfo storage user = users[_token][msg.sender];
        uint result = calculateReward(_token, user.period, user.amount);
        require(pool.poolGrant >= result, "token not granted"); 
        require(calculatePassedTime(_token) >= periods[user.period].periodTime, "Not enough time passed");
        IERC20(pool.token).safeTransfer(msg.sender, user.amount + result);
        pool.poolBalance = pool.poolBalance - user.amount;
        pool.poolGrant = pool.poolGrant - result; 
        user.amount = 0;
        user.timeStart = 0;
        user.period = 0;
        totalUsers--;
        emit RewardClaimed(result);                           
    }
}
