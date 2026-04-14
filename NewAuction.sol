// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract auction{

    uint actualPrice;
    uint bidStep;
    uint endTime;
    address owner;
    address actualWinner;
    bool isOver;
    event bid(address indexed bidder, uint amount, uint time);
    event AuctionEnded(address winner, uint256 winningBid);


    constructor (uint _startPrice, uint _bidStep, uint _duration){
        owner = msg.sender;
        actualPrice = _startPrice;
        bidStep = _bidStep;
        endTime = block.timestamp + _duration;
    }

    function doABid() external payable notOver{
        uint256 minBid;
        if (actualWinner == address(0)) {
            minBid = actualPrice;
        } else {
            minBid = actualPrice + bidStep;
        }
        require(msg.value >= minBid, "Bid too low");
        if (actualWinner != address(0)) {
        (bool success, ) = payable(actualWinner).call{value: actualPrice}("");
        require(success, "Refund failed");
        }
        actualPrice = msg.value;
        actualWinner = msg.sender;
        emit bid(msg.sender, msg.value, block.timestamp);
    }

    function cancelAuction() external onlyOwner{
        require(actualWinner == address(0), "Auction already started");
        isOver = true;
    }

    function endAuction() external{
        require(block.timestamp > endTime, "Auction is not over yet");
        require(!isOver, "Auction is already over");
        isOver = true;
        if (actualWinner != address(0)) {
            (bool success, ) = payable(owner).call{value: actualPrice}("");
            require(success, "Transfer to owner failed");
        }
        emit AuctionEnded(actualWinner, actualPrice);
    }

    modifier onlyOwner{
        require(msg.sender == owner, "You are not an owner");
        _;
    }


    modifier notOver{
        require(block.timestamp <= endTime, "Auction is over");
        require(!isOver, "Auction already ended");
        _;
    }
}