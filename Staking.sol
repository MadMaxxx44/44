// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./SafeERC20.sol";                        
import "@openzeppelin/contracts/access/Ownable.sol";

contract Staking is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    address public rewardToken;             
    uint public totalUsers;  
    uint public time = 60;

    event NewStaker(uint _amount, uint _stakingTime);
    event TokenChanged(address _token);
    event RewardClaimed(uint result);
    event NewPoolCreated(address _token, uint _percentReward, uint _priceToStart);
    
    struct PoolInfo {
        address token;
        uint percentReward;              
        uint priceToStart;
        uint poolBalance;
    }

    struct UserInfo {
        uint amount;
        uint timeStart;
        uint stakingTime;
    }
  
    mapping(address => mapping(address => UserInfo)) public users;
    mapping(address => PoolInfo) public poolInfo;

    constructor(address _token) {
        rewardToken = _token;
    }

    function selfDestruct(address payable _owner) public onlyOwner{
        selfdestruct(_owner);
    }

    function changeToken(address _token) public onlyOwner{    
        rewardToken = _token;
        emit TokenChanged(_token);
    } 
    
    // calculate passed time of staking for user
    function calculatePassedTime(address _token) public view returns(uint timePassed) {
        require(users[_token][msg.sender].amount > 0, "You do not have staked assets");
        return block.timestamp - users[_token][msg.sender].timeStart;
    }

    // 1 period = 60 sec, for easily testing
    function calculateReward(uint _amount, uint _stakingTime, uint _percent) public view returns(uint reward){
        uint periodPassed = _stakingTime/time;
        return _amount*(_percent*periodPassed)/100;
    }

    function poolInstance(address _token, uint _percentReward, uint _priceToStart) public onlyOwner{
        PoolInfo storage pool = poolInfo[_token];
        pool.token = _token;
        pool.percentReward = _percentReward;
        pool.priceToStart = _priceToStart;
        emit NewPoolCreated(_token, _percentReward, _priceToStart);
    }
    
    function stake(uint _amount, address _token, uint _stakingTime) public nonReentrant {
        PoolInfo storage pool = poolInfo[_token];
        UserInfo storage user = users[_token][msg.sender];
        require(_stakingTime >= time, "Wrong staking period");
        require(_amount >= pool.priceToStart, "Not enough amount to start");
        IERC20(pool.token).safeTransferFrom(msg.sender, address(this), _amount);
        user.amount = _amount;
        user.timeStart = block.timestamp;
        user.stakingTime = _stakingTime;
        pool.poolBalance = pool.poolBalance + _amount;
        totalUsers++;
        emit NewStaker(_amount, _stakingTime);
    }

    function unstake(address _token) public nonReentrant returns(uint) {
        PoolInfo storage pool = poolInfo[_token];
        UserInfo storage user = users[_token][msg.sender];
        require(block.timestamp - users[_token][msg.sender].timeStart >= users[_token][msg.sender].stakingTime, "Not enough time passed");
        uint result = calculateReward(user.amount, user.stakingTime, pool.percentReward);
        IERC20(pool.token).safeTransfer(msg.sender, user.amount);
        IERC20(rewardToken).mint(msg.sender, result);
        pool.poolBalance = pool.poolBalance - user.amount;
        user.amount = 0;
        user.timeStart = 0;
        user.stakingTime = 0;
        totalUsers--;
        emit RewardClaimed(result);
        return result;                            
    }
}
