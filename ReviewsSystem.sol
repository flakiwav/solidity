// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract ReviewsSystem{

    address owner;
    uint productsAmount;
    uint reviewsAmount;
    struct Product{
        uint productId;
        string productName;
        string productDescription;
        string productCategory;
        uint reviewsAmount;
        uint reviewsSum;
        bool active;
        bool exists;
        uint[] reviewIds;
    }

    struct Review {
        uint reviewId;
        uint productId;
        address autor;
        string text;
        uint rate;
        uint date;
        uint votesYes;
        uint votesNo;
    }

    Product[] public products;
    Review[] public reviews;
    mapping(address => mapping (uint => bool)) public votesAtReviews;
    mapping(uint => mapping(address => bool)) public hasReviewed;

    constructor(){
        owner = msg.sender;
        productsAmount = 0;
        reviewsAmount = 0;
    }

    function registerProduct(string memory _name, string memory  _description, string memory _category) external{
        products.push(
            Product(productsAmount, _name, _description, _category, 0, 0, true, true, new uint[](0))
        );
        productsAmount++;
    }

    function getProductInfo(uint productId) external view returns(string memory, string memory, string memory, uint, uint){
        return (products[productId].productName, products[productId].productDescription, products[productId].productCategory, products[productId].reviewsSum, products[productId].reviewsAmount);
    }

    function getProductRating(uint256 productId) public view returns (uint256) {
        require(products[productId].reviewsAmount != 0);
        return products[productId].reviewsSum * 100 / products[productId].reviewsAmount;
    }

    function getProductReviews(uint productId, uint fromIndex, uint toIndex) external view returns (uint[] memory){
        Product storage p = products[productId];
        require(p.exists, "Product does not exist");
        require(toIndex <= p.reviewIds.length, "toIndex out of bounds");
        require(fromIndex < toIndex, "Invalid range");
        uint length = toIndex - fromIndex;
        uint[] memory result = new uint[](length);
        for (uint i = 0; i < length; i++) {
            result[i] = p.reviewIds[fromIndex + i];
        }
        return result;
    }

    function blockProduct(uint productId) external onlyOwner{
        products[productId].active = false;
    }

    function unblockProduct(uint productId) external onlyOwner{
        products[productId].active = true;
    }

    function addReview(uint _productId, string memory _text, uint8 _rating) external{
        require(_productId <= products.length-1);
        require(_rating <= 5);
        require(products[_productId].active, "Product is blocked");
        require(!hasReviewed[_productId][msg.sender], "Already reviewed this product");
        uint reviewId = reviewsAmount;
        reviews.push(Review(reviewsAmount, _productId, msg.sender, _text, _rating, block.timestamp, 0, 0));
        products[_productId].reviewIds.push(reviewId); 
        products[_productId].reviewsAmount++;
        products[_productId].reviewsSum += _rating;
        reviewsAmount++;
        hasReviewed[_productId][msg.sender] = true;
    }

    function getReviewInfo(uint reviewId) external view returns (uint, address, string memory, uint, uint, uint, uint){
        return (products[reviews[reviewId].productId].productId, reviews[reviewId].autor, reviews[reviewId].text, reviews[reviewId].rate, reviews[reviewId].date, reviews[reviewId].votesYes, reviews[reviewId].votesNo);
    }

    function getUserReviews(address user) external view returns (Review[] memory){
        uint256 _length;
        for (uint i = 0; i < reviews.length; i++){
            if (reviews[i].autor == user) {_length++;}
        }
        Review[] memory result = new Review[](_length);
        uint _i;
        for (uint i = 0; i < reviews.length; i++) {
            if (reviews[i].autor == user) {result[_i] = reviews[i]; _i++;}

        }
        return result;
    }

    function voteHelpful(uint reviewId) external{
        require(reviews[reviewId].autor != msg.sender);
        require(!votesAtReviews[msg.sender][reviewId]);
        reviews[reviewId].votesYes++;
        votesAtReviews[msg.sender][reviewId] = true;
    }

    function voteNotHelpful(uint reviewId) external{
        require(reviews[reviewId].autor != msg.sender);
        require(!votesAtReviews[msg.sender][reviewId]);
        reviews[reviewId].votesNo++;
        votesAtReviews[msg.sender][reviewId] = true;
    }

    function getPlatformStats() external view onlyOwner returns (uint, uint, uint) {
        uint totalRating = 0;
        uint productsWithRatings = 0;
        for (uint i = 0; i < products.length; i++) {
            if (products[i].reviewsAmount > 0) {
                totalRating += getProductRating(i);
                productsWithRatings++;
            }
        }
    
    uint averageRating = productsWithRatings > 0 ? totalRating / productsWithRatings : 0;
    return (products.length, reviews.length, averageRating);
}

    modifier onlyOwner{
        require(msg.sender == owner);
        _;
    }
}