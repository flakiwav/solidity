// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

enum TaskStatus{ Open, InProgress, Review, Done, Canceled }
enum Priority { Low, Medium, High, Critical }

contract TaskManager{
    struct Task{
        uint id;
        string title;
        string description;
        address creator;
        address assignee;
        TaskStatus status;
        Priority priority;
        uint createdAt;
        uint deadline;
    }
    struct Project{
        uint id;
        string name;
        address owner;
        uint[] taskIds;
    }

    uint tasksCounter;
    uint projectsCounter;
    mapping (uint => Task) tasks;
    uint[] allTaskIds;
    mapping (uint => Project) projects;
    uint[] allProjectIds;
    mapping (uint=>uint) taskToProject;

    event TaskCreated(uint256 indexed taskId, address indexed creator, string title);
    event TaskAssigned(uint256 indexed taskId, address indexed assignee);
    event TaskStatusChanged(uint256 indexed taskId, TaskStatus oldStatus, TaskStatus newStatus);
    event ProjectCreated(uint256 indexed projectId, string name, address owner);
    event TaskAddedToProject(uint256 indexed projectId, uint256 indexed taskId);


    
    constructor() {

    }

    function createTask(string memory _title, string memory _description, uint _deadline, Priority _priority) public returns (uint taskId){
        tasksCounter++;
        taskId = tasksCounter;
        tasks[taskId] = Task(taskId, _title, _description, msg.sender, address(0), TaskStatus.Open, _priority, block.timestamp, _deadline);
        allTaskIds.push(taskId);
        emit TaskCreated(taskId, msg.sender, _title);
        return taskId;
    }

    function assignTask(uint256 taskId, address newAssignee) public taskExists(taskId) onlyCreator(taskId){
        require(newAssignee != address(0), "New assignee cant be zero adress");
        require(newAssignee != tasks[taskId].assignee, "You have to set new assignee");
        require(tasks[taskId].status == TaskStatus.Open, "Task must be open");
        tasks[taskId].assignee = newAssignee;
        emit TaskAssigned(taskId, newAssignee);
    }

    function setTaskStatus(uint256 taskId, TaskStatus newStatus) public taskExists(taskId){
        require(tasks[taskId].status!=TaskStatus.Done, "Task is done");
        require(tasks[taskId].status!=TaskStatus.Canceled, "Task is canceled");
        if (newStatus == TaskStatus.Canceled) {
            require(tasks[taskId].creator == msg.sender, "Only creator can cancel");} 
        else {
            require(msg.sender == tasks[taskId].assignee, "Only assignee can change status");}
        require(newStatus != tasks[taskId].status, "You have to set new status");
        if (newStatus == TaskStatus.InProgress){
            require(tasks[taskId].assignee != address(0), "Task have no assignee");
            require(tasks[taskId].status == TaskStatus.Open || tasks[taskId].status == TaskStatus.Review, "Incorrect status modify");
        }
        if (newStatus == TaskStatus.Review){
            require(tasks[taskId].status == TaskStatus.InProgress, "Incorrect status modify");
        }
        if (newStatus == TaskStatus.Done){
            require(tasks[taskId].status == TaskStatus.Review, "Incorrect status modify");
        }
        TaskStatus oldStatus = tasks[taskId].status;
        tasks[taskId].status = newStatus;
        emit TaskStatusChanged(taskId, oldStatus, newStatus);
    }

    function getTask(uint taskId) public view taskExists(taskId) returns (Task memory) {
        return tasks[taskId];        
    }

    function getTasksByStatus(TaskStatus _status) public view returns (uint[] memory) {
        uint _counter = 0;
        for (uint i = 1; i <= tasksCounter; i++){
            if (tasks[i].status == _status){
                _counter++;
            }
        }

        uint[] memory output = new uint[](_counter);
        uint _i = 0;
        for (uint i = 1; i <= tasksCounter; i++){
            if (tasks[i].status == _status){
                output[_i] = i;
                _i++;
            }
        }
        return output;
    }

    function getTasksByAssignee(address _assignee) public view returns (uint[] memory){
        require(_assignee != address(0));
        uint _counter = 0;
        for (uint i = 1; i <= tasksCounter; i++){
            if (tasks[i].assignee == _assignee){
                _counter++;
            }
        }

        uint[] memory output = new uint[](_counter);
        uint _i = 0;
        for (uint i = 1; i <= tasksCounter; i++){
            if (tasks[i].assignee == _assignee){
                output[_i] = i;
                _i++;
            }
        }
        return output;
    }

    function getOverdueTasks() external view returns (uint256[] memory) {
        uint256 count = 0;
        for (uint256 i = 1; i <= tasksCounter; i++) {
            Task storage task = tasks[i];
            if (task.deadline != 0 &&
                task.deadline < block.timestamp &&
                task.status != TaskStatus.Done &&
                task.status != TaskStatus.Canceled)
            {
                count++;
            }
        }

        uint256[] memory result = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 1; i <= tasksCounter; i++) {
            Task storage task = tasks[i];
            if (task.deadline != 0 &&
                task.deadline < block.timestamp &&
                task.status != TaskStatus.Done &&
                task.status != TaskStatus.Canceled)
            {
                result[index] = i;
                index++;
            }
        }
        return result;
    }

    function createProject(string memory _name) public returns (uint projectId){
        projectsCounter++;
        projectId = projectsCounter;
        uint[] memory emptyArray = new uint[](0);
        projects[projectId] = Project (projectId, _name, msg.sender, emptyArray);
        emit ProjectCreated(projectId, _name, msg.sender);
        return projectId;
    }

    function addTaskToProject(uint256 projectId, uint256 taskId) public taskExists(taskId) projectExists(projectId) onlyProjectOwner(projectId){
        require(taskToProject[taskId] == 0, "This task already in project");
        taskToProject[taskId] = projectId;
        projects[projectId].taskIds.push(taskId);
        emit TaskAddedToProject(projectId, taskId);
    }

    function getTaskCount() external view returns (uint256) {
        return tasksCounter;
    }

    modifier taskExists(uint256 taskId) {
        require(taskId > 0 && taskId <= tasksCounter, "Task does not exist");
        _;
    }

    modifier projectExists(uint256 projectId) {
        require(projectId > 0 && projectId <= projectsCounter, "Project does not exist");
        _;
    }

    modifier onlyCreator(uint256 taskId) {
        require(tasks[taskId].creator == msg.sender, "Not creator");
        _;
    }

    modifier onlyAssignee(uint256 taskId) {
        require(tasks[taskId].assignee == msg.sender, "Not assignee");
        _;
    }

    modifier onlyProjectOwner(uint256 projectId) {
        require(projects[projectId].owner == msg.sender, "Not an owner of project");
        _;
    }
}