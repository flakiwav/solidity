// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PiggyBank {
    string public goalName;
    uint256 public targetAmount;
    uint256 public currentAmount;
    address public owner;
    bool public isActive;
    
    mapping(address => uint256) public deposits;
    
    event Deposit(address indexed from, uint256 amount);
    event Withdraw(address indexed to, uint256 amount);
    event GoalReached(uint256 totalAmount);
    
    constructor(string memory _goalName, uint256 _targetAmount) {
        goalName = _goalName;
        targetAmount = _targetAmount;
        owner = msg.sender;
        isActive = true;
        currentAmount = 0;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier whenActive() {
        require(isActive, "Piggy bank is closed");
        _;
    }

    function deposit() external payable whenActive {
        require(msg.value > 0, "Cannot deposit 0 ETH");
        
        currentAmount += msg.value;
        deposits[msg.sender] += msg.value;
        
        emit Deposit(msg.sender, msg.value);
        
        if (currentAmount >= targetAmount) {
            emit GoalReached(currentAmount);
        }
    }
    
    function getProgress() external view returns (uint256 deposited, uint256 remaining) {
        deposited = currentAmount;
        
        if (currentAmount >= targetAmount) {
            remaining = 0;
        } else {
            remaining = targetAmount - currentAmount;
        }
        
        return (deposited, remaining);
    }
    
    function withdraw() external onlyOwner whenActive {
        require(currentAmount >= targetAmount, "Goal not reached yet");
        
        isActive = false;
        uint256 amountToWithdraw = currentAmount;
        currentAmount = 0; 
        
        payable(owner).transfer(amountToWithdraw);
        
        emit Withdraw(owner, amountToWithdraw);
    }
    
    function getDepositOf(address _depositor) external view returns (uint256) {
        return deposits[_depositor];
    }
    
    function isGoalReached() external view returns (bool) {
        return currentAmount >= targetAmount;
    }
}