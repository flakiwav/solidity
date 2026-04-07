// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract SubscriptionService{
    
    address owner;
    uint platformBalance;
    uint8 platformFee;
    uint lastPlatformFeeUpdate;
    struct creator{
        uint actualPrice;
        bool suspended;
        bool registered;
        address[] activeSubscribers;
    }
    struct subscription{
        uint price;
        uint expireDate;
        //bool isActive;
    }

    mapping (address => creator) creators;
    mapping (address => uint) balances;
    mapping (address => mapping(address => subscription)) subscriptions;

    constructor (){
        owner = msg.sender;
    }
    
    function registerAsCreator(uint _monthlyFee) external{
        require(!creators[msg.sender].suspended);
        require(!creators[msg.sender].registered);
        creators[msg.sender].actualPrice = _monthlyFee;
        creators[msg.sender].registered = true;
    }

    function updateFee(uint _newFee) external{
        creators[msg.sender].actualPrice = _newFee;
    }

    function withdrawEarning() external{
        require(balances[msg.sender] > 0);
        payable(msg.sender).transfer(balances[msg.sender]);
        balances[msg.sender] = 0;
    }

    function getMySubscribers() external view returns (address[] memory) {
        creator storage _creator = creators[msg.sender];
        require(_creator.registered, "Not registered as creator");
        
        uint256 activeCount = 0;
        for (uint i = 0; i < _creator.activeSubscribers.length; i++) {
            if (subscriptions[msg.sender][_creator.activeSubscribers[i]].expireDate > block.timestamp) {
                activeCount++;
            }
        }
        
        address[] memory activeSubscribers = new address[](activeCount);
        uint256 index = 0;
        for (uint i = 0; i < _creator.activeSubscribers.length; i++) {
            if (subscriptions[msg.sender][_creator.activeSubscribers[i]].expireDate > block.timestamp) {
                activeSubscribers[index] = _creator.activeSubscribers[i];
                index++;
            }
        }
        
        return activeSubscribers;
    }

    function renewSubscription (address _creator) external payable{
        require(_creator != address(0));
        require(!creators[_creator].suspended);
        if (subscriptions[_creator][msg.sender].expireDate > block.timestamp){
            require(msg.value >= subscriptions[_creator][msg.sender].price);
            balances[_creator] += subscriptions[_creator][msg.sender].price - (subscriptions[_creator][msg.sender].price * platformFee / 100);
            platformBalance += subscriptions[_creator][msg.sender].price * platformFee / 100;
            subscriptions[_creator][msg.sender].expireDate += 30 days;
        }
        else {subscribe(_creator);}
    }

    function subscribe(address _creator) public payable{
        bool _isNew = true;
        require(_creator != address(0));
        require(!creators[_creator].suspended);
        require(msg.value >= creators[_creator].actualPrice);
        subscriptions[_creator][msg.sender].price = creators[_creator].actualPrice;
        balances[_creator] += subscriptions[_creator][msg.sender].price - (subscriptions[_creator][msg.sender].price * platformFee / 100);
        platformBalance += subscriptions[_creator][msg.sender].price * platformFee / 100;
        subscriptions[_creator][msg.sender].expireDate = block.timestamp + 30 days;
        for (uint i=0; i < creators[_creator].activeSubscribers.length; i++){
            if (creators[_creator].activeSubscribers[i] == msg.sender) {
                _isNew = false;
            }
        }
        if (_isNew == true) {
            creators[_creator].activeSubscribers.push(msg.sender);
        }
    }

    function cancelSubscription(address _creator) external {
    address[] storage subscribers = creators[_creator].activeSubscribers;
    for (uint i = 0; i < subscribers.length; i++) {
        if (subscribers[i] == msg.sender) {
            subscribers[i] = subscribers[subscribers.length - 1];
            subscribers.pop();
            break;
        }
    }
}

    function getSubscriptionStatus(address _creator) external view returns(bool, uint){
        bool _isActive;
        uint _timeToExpire;
        if (subscriptions[_creator][msg.sender].expireDate > block.timestamp){
            _isActive = true;
            _timeToExpire = subscriptions[_creator][msg.sender].expireDate - block.timestamp;
        }
        else {
            _isActive = false;
            _timeToExpire = 0;
        }
        return (_isActive, _timeToExpire);
    }

    function suspendCreator(address _creator) external onlyOwner{
        creators[_creator].suspended = true;
    }

    function activateCreator(address _creator) external onlyOwner{
        creators[_creator].suspended = false;
    }

    function updatePlatformFee(uint8 _newFee) external onlyOwner{
        require(block.timestamp - lastPlatformFeeUpdate > 30 days);
        require(_newFee <= 10);
        platformFee = _newFee;
        lastPlatformFeeUpdate = block.timestamp;
    }

    function withdrawPlatformFees() external onlyOwner{
        payable(owner).transfer(platformBalance);
        platformBalance = 0;
    }

    function getSubscribersCount(address _creator) public view returns (uint) {
        uint count = 0;
        for (uint i = 0; i < creators[_creator].activeSubscribers.length; i++) {
            if (subscriptions[_creator][creators[_creator].activeSubscribers[i]].expireDate > block.timestamp) {
                count++;
            }
        }
        return count;
    }

    function getCreatorInfo(address _creator) public view returns (bool, uint, uint) {
        bool _registered = creators[_creator].registered;
        uint _price = creators[_creator].actualPrice;
        uint _subsCount = getSubscribersCount(_creator);
        return (_registered, _price, _subsCount);
    }
    
    function getSubscriptionExpiry(address _subscriber, address _creator) public view returns (uint){
        require(subscriptions[_creator][_subscriber].expireDate > block.timestamp, "User has no active subscription");
        return (subscriptions[_creator][_subscriber].expireDate);
    }

    function isSubscriptionActive(address _subscriber, address _creator) public view returns (bool) {
    return subscriptions[_creator][_subscriber].expireDate > block.timestamp;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
}

