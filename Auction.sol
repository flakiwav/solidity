// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract SimpleAuction {
    uint public endTime;
    address payable owner;
    uint public minimumBid;
    uint public actualBid = 0;
    address actualWinner;
    mapping(address => uint) public pendingReturns;
    bool auctionEnded;

    event bidsList(address indexed bidder, uint amount);
    event winner(address winner, uint amount);
    event withdraw(address withdrawAddress, uint amount);

    constructor(uint _duration, uint _minimumBid) {
        owner = payable(msg.sender);
        endTime = block.timestamp + (_duration * 1 minutes);
        minimumBid = _minimumBid;
    }

    function bid() external payable{
        require(!auctionEnded);
        require(block.timestamp < endTime, "Auction ended");
        require(msg.value >= minimumBid, "Increase your bid");
        require(msg.value > actualBid, "Increase your bid");
        if (actualWinner != address(0)) {
            pendingReturns[actualWinner] += actualBid;
        }
        actualBid = msg.value;
        actualWinner = msg.sender;
        emit bidsList(msg.sender, msg.value);
    }

    function withdrawYourBet() external{
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "No funds to withdraw");
        pendingReturns[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
    
        emit withdraw(msg.sender, amount);
    }

    function auctionEnd() external onlyOwner{
        require(block.timestamp >= endTime);
        require(!auctionEnded);
        auctionEnded = true;
        emit winner(actualWinner, actualBid);
        owner.transfer(actualBid);
    }

    function timeLeft() external view returns (uint256) {
        if (block.timestamp >= endTime) {
        return 0;
        }
        return endTime - block.timestamp;
    }

    modifier onlyOwner{
        require(msg.sender == owner);
        _;
    }
}