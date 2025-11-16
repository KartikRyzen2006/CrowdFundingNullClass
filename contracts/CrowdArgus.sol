// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

contract CrowdArgus {
        // struct to store project details
        struct Project {
                address creator;
                string name;
                string description;
                uint fundingGoal;
                uint deadline;
                uint fundsRaised;
                bool funded;
        }
        //number of fully-funded projects
        uint public fundedCount;
        //number of partial funded or projects missed the goal
        uint public failedCount;
        //project id => Project details
        mapping(uint => Project) public projects;
        // projectID => user address => amount contributed
        mapping(uint => mapping(address => uint)) public contributions;
        // to keep track of project IDs
        mapping (uint => bool) public isIDUsed;
        
        address public admin; //own this contract
        mapping(address => bool) public isCreator; //whitelist: who can create the projects

        modifier onlyAdmin {
                require(msg.sender == admin,"Only admin can access");
                _;
        }

        modifier onlyCreator {
                require(isCreator[msg.sender],"Only creator can access");
                _;
        }

        constructor() {
                admin = msg.sender; //deployer is admin
                isCreator[msg.sender] = true; //admin can also become creator
        }
        
        //function to add creator
        function addCreator(address _Newcreator) external onlyAdmin {
                isCreator[_Newcreator] = true;
        }
        function removeCreator(address _Creator) external onlyAdmin {
                isCreator[_Creator] = false;
        }


        uint public totalProjects;

        //events (emits when it is called)
        event ProjectCreated(uint indexed projectID, address indexed creator, string name, string description, 
        uint fundingGoal, uint deadline);
        event ProjectFunded(uint indexed projectID, address indexed contributor, uint amount);
        event FundsWithdrawn(uint indexed projectID, address indexed withdrawer, uint amount,
         string withdrawerType);
        event RefundClaimed(uint indexed projectID,address indexed withdrawer,uint amount);
        // event emitted when a refund is issued (withdrawerType = "user","admin")

      //external: can be called outside the contract
        //public: can be called both inside and outside the contract
        //internal: can only be called inside the contract
        //private: can only be called inside the contract


        // project creation 
        //only creator can create project
        function createProject(uint _id, string memory _name, string memory _description,uint _fundingGoal,uint _durationSeconds ) external onlyCreator {
               require(!isIDUsed[_id], "Project ID already used");
               isIDUsed[_id] = true;
         //project created using struct
                          projects [ _id] = Project ({
                          creator: msg.sender,
                          name: _name,
                          description: _description,
                          fundingGoal: _fundingGoal,
                          deadline: block.timestamp + _durationSeconds,
                          fundsRaised: 0,
                          funded: false
                         
               });
        //tracking of total projects created
               totalProjects +=1;
        
         emit ProjectCreated(_id, msg.sender, _name, _description, _fundingGoal, block.timestamp + _durationSeconds);
        }
        //funding of project
        function fundProject(uint _projectId) external payable {
            
                Project storage project = projects[_projectId];
                require(block.timestamp <= project.deadline, "Project deadline has passed");
                require(!project.funded, "Project already funded");
                require(msg.value > 0, "Funding amount must be greater than 0");

                // returns the extra fund to the investor if the investor funds more than fundingGoal
                uint needed = project.fundingGoal - project.fundsRaised;
                uint take   = msg.value > needed ? needed : msg.value;
                uint giveBack = msg.value - take;

                project.fundsRaised += take;
                contributions [_projectId] [msg.sender] += take;

                if (giveBack != 0) payable(msg.sender).transfer(giveBack);
                if (project.fundsRaised == project.fundingGoal) project.funded = true;

                
                emit ProjectFunded(_projectId, msg.sender, take);
        }
        //call this to finalize a project

        function finalizeProject (uint _projectId) private {
                Project storage project = projects[_projectId];
                if (project.funded && project.fundsRaised >= project.fundingGoal) {
                        fundedCount++;

        }else if (block.timestamp > project.deadline && project.fundsRaised < project.fundingGoal) {
                    failedCount++;
        }
        }
        function userWithdrawFunds(uint _projectId) external payable {
                Project storage project = projects [ _projectId];
                require(project.fundsRaised <= project.fundingGoal,"Project was successfully funded, cannot withdraw");
                require(block.timestamp >= project.deadline, "Project still active");
                uint fundContributed = contributions[_projectId][msg.sender];
                payable(msg.sender).transfer(fundContributed);
                contributions[_projectId][msg.sender] = 0; // to prevent re-entrancy attack
                finalizeProject(_projectId); //finalizing the project
                emit FundsWithdrawn(_projectId, msg.sender, fundContributed, "user");
        }

        function adminWithdrawFunds (uint _projectId) external payable {
                Project storage project = projects[_projectId];
                require(msg.sender == project.creator, "Only project creator can withdraw funds");
                require(project.fundsRaised >= project.fundingGoal, "Project successfully funded");
                require( block.timestamp >= project.deadline, "Project is still active");
                uint totalFunding = project.fundsRaised;
                project.fundsRaised = 0; // to prevent re-entrancy attack
                payable(msg.sender).transfer(totalFunding);
                finalizeProject(_projectId); //finalizing the project
                emit FundsWithdrawn(_projectId, msg.sender, totalFunding, "admin");
        }
        //user claiming refunds before deadline passed
        function withdrawContribution ( uint _projectId) external {
        Project storage project = projects [_projectId];
        require(block.timestamp < project.deadline, "Deadline passed");
        require(!project.funded, "Project was successfully funded, cannot withdraw");
        uint fundContributed = contributions[_projectId][msg.sender];
        require (fundContributed > 0, "No funds to withdraw");
        contributions[_projectId][msg.sender] = 0; // to prevent re-entrancy attack
        project.fundsRaised -= fundContributed;
        payable(msg.sender).transfer(fundContributed);

        emit RefundClaimed(_projectId, msg.sender, fundContributed);
        }
        //percentage of funds raised
        function getFundingPercentage  (uint _projectId) public view returns (uint) {
        Project storage project = projects[_projectId];
        if (project.fundingGoal == 0) return 0;
        else {
        return (project.fundsRaised * 100) / project.fundingGoal;
        }
        }

        
}