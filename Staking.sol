// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";                       
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; 
import "@openzeppelin/contracts/access/Ownable.sol";

contract Staking is Ownable, ReentrancyGuard {         
    using SafeERC20 for IERC20;
    IERC20 public rewardToken;             
    uint public totalUsers;  
    uint public periodsCount; 

    event NewStaker(uint _amount, uint _period);
    event TokenChanged(IERC20 _token);
    event RewardClaimed(uint result);
    event NewPoolCreated(IERC20 _token, uint _priceToStart);
    
    struct PoolInfo {
        IERC20 token;            
        uint priceToStart;
        uint poolBalance;
        uint poolLimit;
        uint poolGrant;  //token owner got to grant his tokens before users can stake them
    }

    struct UserInfo {
        uint amount;
        uint timeStart;
        uint period;
    }

    struct PeriodInfo {
        uint periodNumber;
        uint periodTime;
        uint percentReward;
    }
  
    mapping(IERC20 => mapping(address => UserInfo)) public users;
    mapping(IERC20 => PoolInfo) public poolInfo;
    mapping(uint => PeriodInfo) public periods;

    constructor(IERC20 _token) {
        rewardToken = _token;
    }
    
    function changeToken(IERC20 _token) public onlyOwner{    
        rewardToken = _token;
        emit TokenChanged(_token);
    } 
    // calculate passed time of staking for user
    function calculatePassedTime(IERC20 _token) public view returns(uint timePassed) {
        require(users[_token][msg.sender].amount > 0, "You do not have staked assets");
        return block.timestamp - users[_token][msg.sender].timeStart;
    }
    
    function calculateReward(IERC20 _token, uint _amount) public view returns(uint reward) {
        UserInfo storage user = users[_token][msg.sender];
        return _amount*periods[user.period].percentReward / 100;
    }

    function selfDestruct(address payable _owner) public onlyOwner{
        selfdestruct(_owner);
    }

    function addPeriods(uint _periodNumber, uint _periodTime, uint _percentReward) public onlyOwner {
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
        PoolInfo storage pool = poolInfo[_token];
        IERC20(pool.token).safeTransferFrom(msg.sender, address(this), _amount); 
        pool.poolGrant = pool.poolGrant + _amount; 
    }

    function poolInstance(IERC20 _token, uint _priceToStart, uint _poolLimit) public onlyOwner{
        PoolInfo storage pool = poolInfo[_token];
        pool.token = _token;
        pool.priceToStart = _priceToStart;
        pool.poolLimit = _poolLimit;
        emit NewPoolCreated(_token, _priceToStart);
    }
    
    function stake(uint _amount, IERC20 _token, uint _periodNumber) public nonReentrant {
        PoolInfo storage pool = poolInfo[_token];
        UserInfo storage user = users[_token][msg.sender];
        require(_periodNumber <= periodsCount || _periodNumber == 0, "incorrect period");
        require(_amount >= pool.priceToStart, "Not enough amount to start");
        require(pool.poolBalance != pool.poolLimit, "tokens sold out");
        require(pool.poolBalance + _amount <= pool.poolLimit, "try to reduce amount"); 
        IERC20(pool.token).safeTransferFrom(msg.sender, address(this), _amount);
        user.amount = _amount;
        user.timeStart = block.timestamp;
        user.period = periods[_periodNumber].periodNumber; 
        pool.poolBalance = pool.poolBalance + _amount;
        totalUsers++;
        emit NewStaker(_amount, _periodNumber);
    }

    function unstake(IERC20 _token) public nonReentrant {
        PoolInfo storage pool = poolInfo[_token];
        UserInfo storage user = users[_token][msg.sender];
        uint result = calculateReward(_token, user.amount);
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
