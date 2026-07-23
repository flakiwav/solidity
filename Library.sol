// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Library{
    struct Book {
        string title;           // Название книги
        string author;          // Автор
        uint copies;            // Общее количество экземпляров
        uint availableCopies;   // Доступные экземпляры (свободные)
        uint totalRating;       // Сумма всех рейтингов (для вычисления среднего)
        uint ratingCount;       // Количество оценок
        bool exists;            // Флаг, что книга существует (для проверок)
    }

    struct Rental {
        address user;           // Кто арендовал
        uint bookId;            // ID книги
        uint startTime;         // Время начала аренды
        uint endTime;           // Время окончания аренды
        bool returned;          // Возвращена ли книга
    }

    struct UserRental {
        uint bookId;
        uint rentalIndex;  // Индекс в bookRentalHistory[bookId]
}

    mapping(uint => Book) public books;
    uint public bookCounter;
    mapping(address => UserRental[]) public userRentals;
    mapping(uint => Rental[]) public bookRentalHistory;
    mapping(address => mapping(uint => bool)) public userHasRated;
    address owner;

    event BookAdded(uint indexed bookId, string title, string indexed author, uint copies);
    event BookRented(address indexed user, uint indexed bookId, uint indexed rentalId, uint endTime);
    event BookReturned(address indexed user, uint indexed bookId, uint indexed rentalId);
    event BookRated(address indexed user, uint indexed bookId, uint rating);

    constructor (){
        owner = msg.sender;
    }

    function addBook(string memory _title, string memory _author, uint _copies) public onlyOwner{
        require(_copies > 0, "Copies must be greater than 0");
        bookCounter++;
        books[bookCounter] = Book(_title, _author, _copies, _copies, 0, 0, true);
        emit BookAdded(bookCounter, _title, _author, _copies);
    }

    function rentBook(uint _bookId, uint _durationDays) public{
        require(_durationDays > 0, "Duration must be greater than 0");
        require(books[_bookId].exists == true, "Book does not exist");
        require(books[_bookId].availableCopies > 0, "No available copies");
        require(!hasActiveRental(msg.sender, _bookId), "Already rented this book");
        books[_bookId].availableCopies--;
        uint rentalIndex = bookRentalHistory[_bookId].length;
        bookRentalHistory[_bookId].push(Rental(msg.sender, _bookId, block.timestamp, block.timestamp + _durationDays * 1 days, false));
        userRentals[msg.sender].push(UserRental({bookId: _bookId, rentalIndex: rentalIndex}));
        emit BookRented(msg.sender, _bookId, rentalIndex, block.timestamp + _durationDays * 1 days);
    }

    function returnBook(uint _bookId, uint _rentalId) public {
        require(books[_bookId].exists, "Book does not exists");
        require(_rentalId < bookRentalHistory[_bookId].length, "Invalid rental ID");
        require(bookRentalHistory[_bookId][_rentalId].user == msg.sender, "You are not the owner of this rental");
        require(!bookRentalHistory[_bookId][_rentalId].returned, "Book already returned");
        books[_bookId].availableCopies++;
        bookRentalHistory[_bookId][_rentalId].returned = true;
        emit BookReturned(msg.sender, _bookId, _rentalId);
    }

    function rateBook(uint _bookId, uint _rating) public {
        require(books[_bookId].exists, "Book does not exists");    
        require(_rating >= 1 && _rating <= 5, "Invalid rating");
        require(hasUserRentedAndReturned(msg.sender, _bookId), "You must have read and returned this book");
        require(!userHasRated[msg.sender][_bookId], "You have already rated this book");
        books[_bookId].totalRating += _rating;
        books[_bookId].ratingCount++;
        userHasRated[msg.sender][_bookId] = true;
        emit BookRated(msg.sender, _bookId, _rating);
    }

    function getBookInfo(uint _bookId) public view returns (string memory, string memory, uint, uint){
        string memory title = books[_bookId].title;
        string memory author = books[_bookId].author;
        uint availableCopies = books[_bookId].availableCopies;
        uint rating = 0;
        if (books[_bookId].ratingCount > 0) {
            rating = books[_bookId].totalRating * 100 / books[_bookId].ratingCount;
        }
        return (title, author, availableCopies, rating);
    }
    
    function getUserActiveRentals(address _user) public view returns (Rental[] memory) {
        uint activeCount = 0;
        UserRental[] storage userRentalList = userRentals[_user];
    
        for (uint i = 0; i < userRentalList.length; i++) {
            uint bookId = userRentalList[i].bookId;
            uint rentalIndex = userRentalList[i].rentalIndex;
            Rental storage rental = bookRentalHistory[bookId][rentalIndex];
        
            if (!rental.returned) {
                activeCount++;
            }
        }
    
        Rental[] memory activeRentals = new Rental[](activeCount);
        uint counter = 0;
        for (uint i = 0; i < userRentalList.length; i++) {
            uint bookId = userRentalList[i].bookId;
            uint rentalIndex = userRentalList[i].rentalIndex;
            Rental storage rental = bookRentalHistory[bookId][rentalIndex];
        
            if (!rental.returned) {
                activeRentals[counter] = rental;
                counter++;
            }
        }   
    
        return activeRentals;
    }

    function getBookRentalHistory(uint _bookId) public view returns (Rental[] memory){
        uint rentalsCount = bookRentalHistory[_bookId].length;
        Rental[] memory rentalList = new Rental[](rentalsCount);
        for (uint i = 0; i < rentalsCount; i++){
            rentalList[i] = bookRentalHistory[_bookId][i];
        }
        return rentalList;
    }

    function getAvailableBooks() public view returns(uint[] memory){
        uint availableBooksCount = 0;
        for (uint i = 1; i <= bookCounter; i++){
            if (books[i].availableCopies > 0){
                availableBooksCount++;
            }
        }

        uint counter = 0;
        uint[] memory bookIds= new uint[](availableBooksCount);
        for (uint i = 1; i <= bookCounter; i++){
            if (books[i].availableCopies > 0){
                bookIds[counter] = i;
                counter++;
            }
        }
        return bookIds;
    }

    function hasActiveRental(address _user, uint _bookId) private view returns (bool) {
        for (uint i = 0; i < userRentals[_user].length; i++) {
            if (userRentals[_user][i].bookId == _bookId) {
                uint rentalIndex = userRentals[_user][i].rentalIndex;
                if (!bookRentalHistory[_bookId][rentalIndex].returned) {
                    return true;
                }
            }
    }
    return false;   
    }

    function hasUserRentedAndReturned(address _user, uint _bookId) private view returns (bool) {
        UserRental[] storage rentals = userRentals[_user];
        for (uint i = 0; i < rentals.length; i++) {
        if (rentals[i].bookId == _bookId) {
            uint index = rentals[i].rentalIndex;
            Rental storage rental = bookRentalHistory[_bookId][index];
            if (rental.returned) {
                return true;
            }
        }
    }
    return false;
    }

    modifier onlyOwner{
        require(msg.sender == owner);
        _;
    }
}