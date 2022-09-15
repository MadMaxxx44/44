// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./SafeERC20.sol";                        
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingPerpetual is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    IERC20 public rewardToken; //contract got to own this token, to mint reward for stakers           
    uint public totalUsers;
    uint public Period;

    event NewStaker(uint _amount);
    event TokenChanged(IERC20 _token);
    event RewardClaimed(uint result);
    event NewPoolCreated(IERC20 _token, uint _percentReward, uint _priceToStart);
    
    struct PoolInfo {
        IERC20 token;
        uint percentReward;              
        uint priceToStart;
        uint poolBalance;
        uint poolLimit;
        uint minimum; //minimum time in seconds that user can stake tokens
        address tokenOwner; //when create a pool, token owner got to transfer ownership to contract
    }                       //this variable created for transfering ownership back to owner after

    struct UserInfo {
        uint amount;
        uint timeStart;
    }
  
    mapping(IERC20 => mapping(address => UserInfo)) public users;
    mapping(IERC20 => PoolInfo) public poolInfo;

    constructor(IERC20 _token) {
        rewardToken = _token;
        Period = 60; // for conveniet testing
    }

    function selfDestruct(address payable _owner) public onlyOwner {
        selfdestruct(_owner);
    }
    //when change token dont forget to transfer ownership
    function changeToken(IERC20 _token) public onlyOwner {    
        rewardToken = _token;
        emit TokenChanged(_token);
    }  
    //owner set period in seconds, this will impact on calculateReward function
    //thus owner can regulate stakers rewards for example when Period = 60 and pool percentReward = 10, 
    //staker will receive 10 tokens as reward from 100 tokens staked within 1 min
    function setPeriod(uint _period) public onlyOwner {              
        Period = _period; 
    }
        
    function calculateReward(IERC20 _token) public view returns(uint) {
        PoolInfo storage pool = poolInfo[_token];
        UserInfo storage user = users[_token][msg.sender];
        require(user.amount > 0, "You do not have staked assets");
        return user.amount*pool.percentReward/100 * timePassed(_token) / Period;
    }

    function timePassed(IERC20 _token) public view returns(uint) {
        UserInfo storage user = users[_token][msg.sender];
        require(user.amount > 0, "You do not have staked assets");
        return block.timestamp - user.timeStart; 
    }

    function poolInstance(IERC20 _token, uint _percentReward, uint _priceToStart, uint _poolLimit, uint _minimum, address _tokenOwner) public onlyOwner {
        PoolInfo storage pool = poolInfo[_token];
        pool.token = _token; 
        pool.percentReward = _percentReward;
        pool.priceToStart = _priceToStart;
        pool.poolLimit = _poolLimit;
        pool.minimum = _minimum;
        pool.tokenOwner = _tokenOwner; 
        emit NewPoolCreated(_token, _percentReward, _priceToStart);
    }

    function stake(uint _amount, IERC20 _token) public nonReentrant {
        PoolInfo storage pool = poolInfo[_token];
        UserInfo storage user = users[_token][msg.sender];
        require(Period >= 60, "incorrect period");
        require(pool.poolBalance != pool.poolLimit, "sold out"); 
        require(pool.poolBalance + _amount <= pool.poolLimit, "reduce amount"); 
        require(_amount >= pool.priceToStart, "Not enough amount to start");
        require(user.amount == 0, "you can not stake again"); 
        IERC20(pool.token).safeTransferFrom(msg.sender, address(this), _amount);
        user.amount = user.amount + _amount;
        user.timeStart = block.timestamp;
        pool.poolBalance = pool.poolBalance + _amount;
        totalUsers++;
        emit NewStaker(_amount);
    }

    function unstake(IERC20 _token) public nonReentrant {
        PoolInfo storage pool = poolInfo[_token];
        UserInfo storage user = users[_token][msg.sender];
        require(user.amount > 0, "u need to stake first");
        require(timePassed(_token) >= pool.minimum, "not enough minimum staking time passed");
        uint reward = calculateReward(_token);  
        IERC20(rewardToken).mint(msg.sender, user.amount + reward); 
        pool.poolBalance = pool.poolBalance - user.amount;
        user.amount = 0;
        user.timeStart = 0;
        totalUsers--;
        emit RewardClaimed(reward);
    }
}
