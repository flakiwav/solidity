// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Bank{
    uint8 rate = 5;
    uint8 loanRate = 10;
    address owner;
    struct Balance {
        uint balance;
        uint lastDepositTime;
    }
    struct Loan {
        uint loan;
        uint loanTime;
        bool active;
    }
    mapping (address=>Balance) allBalances;
    mapping (address=>Loan) public loans;
    event Deposited(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event LoanTaken(address indexed user, uint256 amount);
    event LoanRepaid(address indexed user, uint256 amount);
    event Liquidated(address indexed user, address indexed liquidator, uint256 deposit, uint256 debt);

    constructor(){
        owner = msg.sender;
    }

    function deposit() external payable {
        allBalances[msg.sender].balance = countMyBalance(msg.sender);
        allBalances[msg.sender].balance += msg.value;
        allBalances[msg.sender].lastDepositTime = block.timestamp;
        emit Deposited(msg.sender, msg.value);
    }

    function countMyBalance(address addr) public view returns(uint) {
        uint _myBalance;
        uint256 _timePassed;
        if (allBalances[addr].balance == 0) {return 0;}
        else {
            _timePassed = block.timestamp - allBalances[addr].lastDepositTime;
            _myBalance = allBalances[addr].balance + (allBalances[addr].balance * rate * _timePassed / (100 * 365 days));
            return _myBalance;
        }
    }

    function getCurrentDebt(address addr) public view returns (uint256) {
        Loan memory userLoan = loans[addr];
        if (!userLoan.active || userLoan.loan == 0) {
         return 0;
        }
        uint256 timePassed = block.timestamp - userLoan.loanTime;
        if (timePassed == 0) {
           return userLoan.loan;
        }
        uint256 interest = userLoan.loan * loanRate * timePassed / (100 * 365 days);
        return userLoan.loan + interest;
}

    function withdraw(uint _value) external {
        require(_value > 0, "Cannot withdraw 0 ETH");
        uint256 _currentBalance = countMyBalance(msg.sender);
        require(_currentBalance >= _value, "Not enought balance"); 
        require(!loans[msg.sender].active, "Repay loan first");
        allBalances[msg.sender].balance = _currentBalance - _value;
        allBalances[msg.sender].lastDepositTime = block.timestamp;
        payable(msg.sender).transfer(_value);
        emit Withdraw(msg.sender, _value);
    }

    function takeLoan(uint256 _amount) external {
        require(_amount > 0, "Cannot take 0 loan");
        uint256 maxLoan = countMyBalance(msg.sender) * 50 / 100;
        require(_amount <= maxLoan, "Loan amount exceeds maximum allowed");
        require(!loans[msg.sender].active, "Existing loan. Repay first");
        allBalances[msg.sender].balance = countMyBalance(msg.sender);
        allBalances[msg.sender].lastDepositTime = block.timestamp;
        loans[msg.sender] = Loan({
            loan: _amount,
            loanTime: block.timestamp,
            active: true
        });
        payable(msg.sender).transfer(_amount);
    
        emit LoanTaken(msg.sender, _amount);
    }

    function repayLoan() external payable{
        uint256 currentDebt = getCurrentDebt(msg.sender);
        require(currentDebt > 0, "No active loan");
        require(msg.value >= currentDebt, "Insufficient payment");
        loans[msg.sender].loan = 0;
        loans[msg.sender].active = false;
        uint256 excess = msg.value - currentDebt;
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }
        uint256 currentDeposit = countMyBalance(msg.sender);
        allBalances[msg.sender].balance = currentDeposit;
        allBalances[msg.sender].lastDepositTime = block.timestamp;
        emit LoanRepaid(msg.sender, currentDebt);
    }

    function liquidate(address _user) external {
        uint256 currentDeposit = countMyBalance(_user);
        uint256 currentDebt = getCurrentDebt(_user);
        require(currentDebt > 0, "No active loan");
        uint256 liquidationLimit = currentDeposit * 80 / 100;
        require(currentDebt > liquidationLimit, "Position is healthy");
        if (currentDeposit >= currentDebt) {
            uint256 remainder = currentDeposit - currentDebt;
            allBalances[_user].balance = 0;
            loans[_user].active = false;
            loans[_user].loan = 0;
        if (remainder > 0) {
            payable(_user).transfer(remainder);
        }
        } else {
            allBalances[_user].balance = 0;
            loans[_user].loan = currentDebt - currentDeposit;
            loans[_user].loanTime = block.timestamp;
        }
    
        emit Liquidated(_user, msg.sender, currentDeposit, currentDebt);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }


}