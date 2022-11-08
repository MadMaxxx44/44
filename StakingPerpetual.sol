// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

//deployed at goerli 0xb3B9D62cB0662b4f31bA5eA8AC80950b119cFD8d

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";            
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingPerpetual is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;          
    uint public totalUsers;
    uint public Period; //time in seconds after which user accumulate percentReward

    event NewStaker(uint _amount);
    event TokenChanged(IERC20 _token);
    event RewardClaimed(uint result);
    event NewPoolCreated(IERC20 _token, uint _percentReward, uint _priceToStart);
    event TokenGranted(IERC20 _token, uint _amount); 
    
    struct PoolInfo {
        IERC20 token;
        uint percentReward;              
        uint priceToStart;
        uint poolBalance;
        uint poolLimit;
        uint poolGrant; //pool got to be granted before users can unstake their assets 
        uint minimum; //minimum time in seconds that user can stake tokens
    }                       

    struct UserInfo {
        uint amount;
        uint timeStart;
    }
  
    mapping(IERC20 => mapping(address => UserInfo)) public users;
    mapping(IERC20 => PoolInfo) public poolInfo;

    constructor() {
        Period = 60; // for conveniet testing
    }

    fallback() external {}
    receive() external payable {}

    function selfDestruct(address payable _owner) public onlyOwner {
        selfdestruct(_owner);
    } 
    //owner set period in seconds, this will impact on calculateReward function
    //thus owner can regulate stakers rewards for example when Period = 60 and pool percentReward = 10, 
    //staker will receive 10 tokens as reward from 100 tokens staked every minute
    function setPeriod(uint _period) public onlyOwner {              
        Period = _period; 
    }
    //calculate rewards for stakers
    function calculateReward(IERC20 _token) public view returns(uint) {
        PoolInfo storage pool = poolInfo[_token];
        UserInfo storage user = users[_token][msg.sender];
        require(user.amount > 0, "you do not have staked assets");
        return user.amount*pool.percentReward/100 * timePassed(_token) / Period;
    }
    //calculate passed time for staker 
    function timePassed(IERC20 _token) public view returns(uint) {
        UserInfo storage user = users[_token][msg.sender];
        require(user.amount > 0, "you do not have staked assets");
        return block.timestamp - user.timeStart; 
    }
    
    function grantToken(IERC20 _token, uint _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_token];
        IERC20(pool.token).safeTransferFrom(msg.sender, address(this), _amount); 
        pool.poolGrant = pool.poolGrant + _amount; 
        emit TokenGranted(_token, _amount); 
    }

    function poolInstance(IERC20 _token, uint _percentReward, uint _priceToStart, uint _poolLimit, uint _minimum) public onlyOwner {
        PoolInfo storage pool = poolInfo[_token];
        pool.token = _token; 
        pool.percentReward = _percentReward;
        pool.priceToStart = _priceToStart;
        pool.poolLimit = _poolLimit;
        pool.minimum = _minimum;
        emit NewPoolCreated(_token, _percentReward, _priceToStart);
    }

    function stake(uint _amount, IERC20 _token) public nonReentrant {
        PoolInfo storage pool = poolInfo[_token];
        UserInfo storage user = users[_token][msg.sender];
        require(Period >= 60, "incorrect period");
        require(pool.poolBalance != pool.poolLimit, "sold out"); 
        require(pool.poolBalance + _amount <= pool.poolLimit, "reduce amount"); //prevents overflow of pool limit
        require(_amount >= pool.priceToStart, "not enough amount to start");
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
        uint reward = calculateReward(_token);
        require(user.amount > 0, "you need to stake first");
        require(pool.poolGrant >= reward, "token not granted");
        require(timePassed(_token) >= pool.minimum, "not enough minimum staking time passed");
        IERC20(_token).safeTransfer(msg.sender, user.amount + reward); 
        pool.poolBalance = pool.poolBalance - user.amount;
        pool.poolGrant = pool.poolGrant - reward;
        user.amount = 0;
        user.timeStart = 0;
        totalUsers--;
        emit RewardClaimed(reward);
    }
}
