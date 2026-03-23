// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

contract Voting {

    address public owner;
    mapping (address=>bool) alreadyVoted;
    struct Candidate {
        //uint id;
        string name;
        uint voteCount;
    }
    Candidate[] public candidates;
    bool voteActive;
    event voted (address indexed voter, uint candidateId, string candidateName);

    constructor(string[] memory _candidates){
        require(_candidates.length > 0, "At least one candidate required");
        for (uint i = 0; i < _candidates.length; i++){
            candidates.push(Candidate(_candidates[i], 0));
        }
        owner = msg.sender;
        voteActive = true;
    }

    function voting(uint _candidateId) external{
        require(voteActive, "Not Active");
        require(!alreadyVoted[msg.sender], "Already Voted");
        require(_candidateId < candidates.length, "Candidate Does Not Exist");
        candidates[_candidateId].voteCount ++;
        alreadyVoted[msg.sender] = true;
        emit voted(msg.sender, _candidateId, candidates[_candidateId].name);
    }

    function getVoteCounts() external view returns(uint[] memory){
        uint[] memory _countOfVotes = new uint[](candidates.length);
        for (uint i = 0; i < candidates.length; i++){
            _countOfVotes[i] = candidates[i].voteCount;
        }

        return _countOfVotes;
    }

    function endVoting() external onlyOwner{
        voteActive = false;
    }

    function getWinner() external view returns (string memory, uint) {
        require(!voteActive, "Voting Is Active");
        uint maxVotes = 0;
        uint winnerId = 0;
    
        for (uint i = 0; i < candidates.length; i++) {
            if (candidates[i].voteCount > maxVotes) {
                maxVotes = candidates[i].voteCount;
                winnerId = i;
            }
        }
    
        return (candidates[winnerId].name, maxVotes);
    }

    function getCandidates() external view returns (string[] memory) {
        string[] memory names = new string[](candidates.length);
        for (uint i = 0; i < candidates.length; i++) {
            names[i] = candidates[i].name;
        }
        return names;
    }

    function getCandidateCount() external view returns (uint) {
        return candidates.length;
    }

    modifier onlyOwner{
        require(msg.sender == owner);
        _;
    }
}
