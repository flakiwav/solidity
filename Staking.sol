// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract StakingPool {
    struct Stake {
        uint256 amount;           // Сумма стейка
        uint256 startTime;        // Время начала стейкинга
        uint256 lockDuration;     // Длительность блокировки (в секундах)
        uint256 rewardRate;       // Процент награды для этого стейка
        bool isActive;            // Активен ли стейк
    }
    
    uint256 public constant LOCK_1_MONTH = 30 days;
    uint256 public constant LOCK_3_MONTHS = 90 days;
    uint256 public constant LOCK_6_MONTHS = 180 days;
    uint256 public constant LOCK_12_MONTHS = 365 days;
    
    uint256 public REWARD_1_MONTH = 2;   // 2%
    uint256 public REWARD_3_MONTHS = 7;  // 7%
    uint256 public REWARD_6_MONTHS = 15; // 15%
    uint256 public REWARD_12_MONTHS = 30; // 30%
    
    uint256 public constant EARLY_WITHDRAWAL_PENALTY = 5; // 5% штраф
    
    mapping(address => Stake[]) public stakes;
    uint256 public totalStaked;
    uint256 public rewardPool;
    
    address public owner;
    uint256 public lastRateChangeTime;
    
    event Staked(address indexed user, uint256 amount, uint256 lockDuration, uint256 rewardRate);
    event Withdrawn(address indexed user, uint256 amount, uint256 reward, bool early);
    event RewardsAdded(uint256 amount);
    event RewardRateChanged(uint256 newRate, uint256 lockDuration);
    
    constructor() {
        owner = msg.sender;
        lastRateChangeTime = block.timestamp;
    }
    
    function stake(uint256 _lockDuration) public payable {
        require(msg.value > 0, "Cannot stake 0 ETH");

        uint256 rewardRate;
        if (_lockDuration == LOCK_1_MONTH) {
        rewardRate = REWARD_1_MONTH;      
        } else if (_lockDuration == LOCK_3_MONTHS) {
        rewardRate = REWARD_3_MONTHS;    
        } else if (_lockDuration == LOCK_6_MONTHS) {
        rewardRate = REWARD_6_MONTHS;   
        } else if (_lockDuration == LOCK_12_MONTHS) {
        rewardRate = REWARD_12_MONTHS;  
        } else revert("Invalid lock duration");
    
        stakes[msg.sender].push(Stake({
            amount: msg.value,
            startTime: block.timestamp,
            lockDuration: _lockDuration,
            rewardRate: rewardRate,
            isActive: true
        }));
    
        totalStaked += msg.value;
    
        emit Staked(msg.sender, msg.value, _lockDuration, rewardRate);
    }
    
    function withdraw(uint256 _stakeId) external {
        require(stakes[msg.sender].length != 0, "You have no staked ETH");
        require(stakes[msg.sender].length - 1 >= _stakeId, "Stake does not exsist");
        require(stakes[msg.sender][_stakeId].isActive, "Stake is not active");

        if (block.timestamp - stakes[msg.sender][_stakeId].startTime >= stakes[msg.sender][_stakeId].lockDuration){
            totalStaked -= (stakes[msg.sender][_stakeId].amount);
            rewardPool -= stakes[msg.sender][_stakeId].amount * stakes[msg.sender][_stakeId].rewardRate;
            stakes[msg.sender][_stakeId].isActive = false;
            payable(msg.sender).transfer(stakes[msg.sender][_stakeId].amount + stakes[msg.sender][_stakeId].amount * stakes[msg.sender][_stakeId].rewardRate);
            emit Withdrawn(msg.sender, stakes[msg.sender][_stakeId].amount + stakes[msg.sender][_stakeId].amount * stakes[msg.sender][_stakeId].rewardRate, stakes[msg.sender][_stakeId].amount * stakes[msg.sender][_stakeId].rewardRate, false);
        }

        if (block.timestamp - stakes[msg.sender][_stakeId].startTime < stakes[msg.sender][_stakeId].lockDuration){
            totalStaked -= (stakes[msg.sender][_stakeId].amount);
            rewardPool += stakes[msg.sender][_stakeId].amount * EARLY_WITHDRAWAL_PENALTY / 100;
            stakes[msg.sender][_stakeId].isActive = false;
            payable(msg.sender).transfer(stakes[msg.sender][_stakeId].amount - stakes[msg.sender][_stakeId].amount * EARLY_WITHDRAWAL_PENALTY / 100);
            emit RewardsAdded(stakes[msg.sender][_stakeId].amount * EARLY_WITHDRAWAL_PENALTY / 100);
            emit Withdrawn(msg.sender, stakes[msg.sender][_stakeId].amount - stakes[msg.sender][_stakeId].amount * EARLY_WITHDRAWAL_PENALTY / 100, 0, true);
        }
    }
    
    function getMyStakes() external view returns (Stake[] memory) {
        require(stakes[msg.sender].length != 0, "You have no staked ETH");
        return stakes[msg.sender];
    }
    
    function calculateReward(Stake memory _stake) public view returns (uint256 reward, bool isEarly) {
        uint256 timePassed = block.timestamp - _stake.startTime;
        if (timePassed >= _stake.lockDuration) {
            reward = _stake.amount * _stake.rewardRate / 100;
            isEarly = false;
        } else {
            reward = 0;
            isEarly = true;  
    }
    }
    
    function addRewards() external payable onlyOwner {
         rewardPool += msg.value;
         emit RewardsAdded(msg.value);
    }
    
    function setRewardRate(uint256 _lockDuration, uint256 _newRate) external onlyOwner {
        require(block.timestamp - lastRateChangeTime >= 30 days);
        require(_newRate <= 100 && _newRate != 0);
        if (_lockDuration == LOCK_1_MONTH){REWARD_1_MONTH = _newRate;}
        else if (_lockDuration == LOCK_3_MONTHS){REWARD_3_MONTHS = _newRate;}
        else if (_lockDuration == LOCK_6_MONTHS){REWARD_6_MONTHS = _newRate;}
        else if (_lockDuration == LOCK_12_MONTHS){REWARD_12_MONTHS = _newRate;}
        lastRateChangeTime = block.timestamp;
    }
    
    function compound(uint256 _stakeId, uint256 _newLockDuration) external {
        require(_stakeId < stakes[msg.sender].length, "Stake does not exist");
        Stake storage userStake = stakes[msg.sender][_stakeId];
        require(userStake.isActive, "Stake is not active");
        (uint256 reward, bool isEarly) = calculateReward(userStake);
        require(!isEarly, "Cannot compound before lock period ends");
        uint256 totalAmount = userStake.amount + reward;
        totalStaked -= userStake.amount;
        userStake.isActive = false;
        if (reward > 0) {
            if (rewardPool >= reward) {
                rewardPool -= reward;
            } else {
                reward = 0;
            }
        }
        uint256 newRewardRate;
        if (_newLockDuration == LOCK_1_MONTH) {
            newRewardRate = REWARD_1_MONTH;
        } else if (_newLockDuration == LOCK_3_MONTHS) {
            newRewardRate = REWARD_3_MONTHS;
        } else if (_newLockDuration == LOCK_6_MONTHS) {
            newRewardRate = REWARD_6_MONTHS;
        } else if (_newLockDuration == LOCK_12_MONTHS) {
            newRewardRate = REWARD_12_MONTHS;
        } else {
            revert("Invalid lock duration");
        }
        stakes[msg.sender].push(Stake({
            amount: totalAmount,
            startTime: block.timestamp,
            lockDuration: _newLockDuration,
            rewardRate: newRewardRate,
            isActive: true
        }));
        totalStaked += totalAmount;
        emit Staked(msg.sender, totalAmount, _newLockDuration, newRewardRate);
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
}