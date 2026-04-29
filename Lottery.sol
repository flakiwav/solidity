// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract Lottery{
    
    address owner;
    address winner;
    uint maxTickets;
    uint endTime;
    uint public ticketPrice;
    uint comission;
    uint prizePool;
    uint fees;
    uint ticketsValue;
    uint lastFeeChange;
    uint lotteriesValues;
    mapping (uint => mapping (address => uint[])) tickets;
    mapping (uint => mapping (uint => address)) owners;
    mapping (uint => address) winners;
    bool ended;

    constructor(uint _maxTickets, uint _endTime, uint _price, uint _comission){
        owner = msg.sender;
        maxTickets = _maxTickets;
        endTime = block.timestamp + _endTime;
        ticketPrice = _price;
        comission = _comission;
        lastFeeChange = block.timestamp;
        ended = false;
    }

    function buyTickets(uint _numberOfTickets) external payable notEnded{
        require(_numberOfTickets > 0);
        require(msg.value == ticketPrice * _numberOfTickets);
        require(ticketsValue + _numberOfTickets <= maxTickets);
        uint256 _commissionAmount = msg.value * comission / 100;
        fees += _commissionAmount;
        prizePool += msg.value - _commissionAmount;
        for (uint i; i < _numberOfTickets; i++){
            tickets[lotteriesValues][msg.sender].push(ticketsValue);
            owners[lotteriesValues][ticketsValue] = msg.sender;
            ticketsValue++;
        }
    }

    function getMyTickets() public view returns(uint[] memory){
        return tickets[lotteriesValues][msg.sender];
    }

    function getTicketOwner(uint _ticketId) public view returns(address){
        return owners[lotteriesValues][_ticketId];
    }

    function getCurrentLotteryInfo() external view returns(uint, uint, uint, uint, uint){
        return (maxTickets, endTime, ticketPrice, prizePool, ticketsValue);
    }

    function _random(uint256 max) internal view returns (uint256) {
    return uint256(keccak256(abi.encodePacked(
        blockhash(block.number - 1),
        block.timestamp,
        ticketsValue
    ))) % max;
    }

    function drawWinner() external returns(address){
        require((ticketsValue == maxTickets) || (block.timestamp >= endTime), "Conditions not met");
        require(!ended, "Already drawn");
        require(ticketsValue > 0, "No tickets sold");
        uint ticketWinner = _random(ticketsValue);
        address winnerAddress = getTicketOwner(ticketWinner);
        uint256 prize = prizePool;
        prizePool = 0;
        (bool success, ) = payable(winnerAddress).call{value: prize}("");
        require(success, "Transfer failed");
        winners[lotteriesValues] = winnerAddress;
        ended = true;
        return winners[lotteriesValues];
    }

    function setMaxTickets(uint newMax) external onlyOwner{
        require(!ended, "Lottery already ended");
        require(newMax >= ticketsValue, "New max cannot be less than sold tickets");
        maxTickets = newMax;
    }

    function setTimeout(uint newTimeout) external onlyOwner{
        require(!ended);
        endTime = block.timestamp + newTimeout;
    }

    function setPlatformFee(uint8 newFee) external onlyOwner{
        require(block.timestamp - lastFeeChange > 30 days);
        comission = newFee;
    }

    function withdrawFees() external onlyOwner{
        (bool success, ) = owner.call{value: fees}("");
        require(success, "Transfer failed");
        fees = 0;
    }

    function startNewLottery(uint _maxTickets, uint _endTime, uint _price) external onlyOwner{
        require(ended);
        maxTickets = _maxTickets;
        endTime = block.timestamp + _endTime;
        ticketPrice = _price;
        lotteriesValues ++;
        ticketsValue = 0;
        ended = false;
    }

    function getLotteryHistory(uint lotteryId) external view returns(address){
        return winners[lotteryId];
    }

    modifier notEnded{
        require(endTime > block.timestamp);
        _;
    }

    modifier onlyOwner{
        require(msg.sender == owner);
        _;
    }

}