// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Arcalis {
    address public contractOwner;
    uint256 public level2Price = 0.0002 ether;
    uint256 public level3Price = 0.0003 ether;
    uint256 public level4Price = 0.0004 ether;
    uint256 public contractSharePercentage = 10; 

    address[] public coOwners;

    mapping(address => uint256) public userLevel;
    mapping(address => uint256) public userSubscriptionTime;

    struct Proposal {
        address creator;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 endTime;
        bool executed;
        mapping(address => bool) voted;
    }

    Proposal[] public proposals;
    uint256 public constant MAX_OPEN_PROPOSALS = 5;
    mapping(address => bool) public blacklist;

    event PackagePurchased(address indexed user, uint256 level);
    event ProposalCreated(uint256 indexed proposalId, string description);
    event Voted(address indexed voter, uint256 indexed proposalId, bool support);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalDeleted(uint256 indexed proposalId);
    event Blacklisted(address indexed user);
    event Unblacklisted(address indexed user);
    event CoOwnerAdded(address indexed coOwner);
    event CoOwnerRemoved(address indexed coOwner);
    event ContractSharePercentageUpdated(uint256 newPercentage);
    event EmergencyProposalCreated(uint256 indexed proposalId, string description, uint256 durationHours);


    constructor() {
        contractOwner = msg.sender;
    }

    modifier onlyOwnerOrCoOwner() {
        require(
            msg.sender == contractOwner || isCoOwner(msg.sender),
            "Only owner or co-owner can perform this action"
        );
        _;
    }
     modifier onlyOwnerCoOwnerOrLevel4() {
        require(
            msg.sender == contractOwner || isCoOwner(msg.sender) || userLevel[msg.sender] == 4,
            "Only owner, co-owner, or Level 4 can perform this action"
        );
        _;
    }
    function createEmergencyVote(string memory description, uint256 durationHours)
        public
        onlyOwnerOrCoOwner
    {
        require(durationHours > 0, "Duration must be at least 1 hour");
        require(getOpenProposalsCount() < MAX_OPEN_PROPOSALS, "Maximum open proposals reached");

        Proposal storage newProposal = proposals.push();
        newProposal.creator = msg.sender;
        newProposal.description = description;
        newProposal.endTime = block.timestamp + (durationHours * 1 hours);

        emit EmergencyProposalCreated(proposals.length - 1, description, durationHours);
    }

    function purchasePackage(uint256 level) public payable {
        require(level >= 2 && level <= 4, "Invalid level");

        uint256 price = getPackagePrice(level);
        require(msg.value == price, "Incorrect amount");

        uint256 contractShare = (price * contractSharePercentage) / 100;
        uint256 remainder = price - contractShare;

        userLevel[msg.sender] = level;
        userSubscriptionTime[msg.sender] = block.timestamp;

        payable(contractOwner).transfer(remainder);

        emit PackagePurchased(msg.sender, level);
    }

    function getPackagePrice(uint256 level) public view returns (uint256) {
        if (level == 2) return level2Price;
        if (level == 3) return level3Price;
        return level4Price;
    }

    modifier onlyOwner() {
    require(msg.sender == contractOwner, "Only owner can perform this action");
    _;
}

function updateContractSharePercentage(uint256 newPercentage) public onlyOwner {
    require(newPercentage >= 0 && newPercentage <= 100, "Percentage must be between 0 and 100");
    contractSharePercentage = newPercentage;
    emit ContractSharePercentageUpdated(newPercentage);
}


    function isSubscriptionActive() public view returns (bool) {
        uint256 subscriptionTime = userSubscriptionTime[msg.sender];
        if (subscriptionTime == 0) return false; 
        return block.timestamp <= subscriptionTime + 30 days;
    }

    function getVoteWeight(address voter) public view returns (uint256) {
        uint256 level = userLevel[voter];
        if (level == 2) return 1;
        if (level == 3) return 2;
        if (level == 4) return 3;
        return 0;
    }

    function createProposal(string memory description, uint256 durationDays)
        public
        onlyOwnerCoOwnerOrLevel4
    {
        require(durationDays > 0, "Duration must be at least 1 day");
        require(getOpenProposalsCount() < MAX_OPEN_PROPOSALS, "Maximum open proposals reached");

        Proposal storage newProposal = proposals.push();
        newProposal.creator = msg.sender;
        newProposal.description = description;
        newProposal.endTime = block.timestamp + (durationDays * 1 days);

        emit ProposalCreated(proposals.length - 1, description);
    }

    function getOpenProposalsCount() public view returns (uint256 count) {
        for (uint256 i = 0; i < proposals.length; i++) {
            if (!proposals[i].executed && block.timestamp < proposals[i].endTime) {
                count++;
            }
        }
    }

    function voteOnProposal(uint256 proposalId, bool support) public {
        require(!isBlacklisted(msg.sender), "You are blacklisted and cannot vote.");
        require(userLevel[msg.sender] >= 2, "Only Level 2 or above can vote");
        require(proposalId < proposals.length, "Invalid proposal ID");

        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp < proposal.endTime, "Voting period has ended");
        require(!proposal.voted[msg.sender], "You have already voted");

        uint256 voteWeight = getVoteWeight(msg.sender);
        if (support) {
            proposal.votesFor += voteWeight;
        } else {
            proposal.votesAgainst += voteWeight;
        }

        proposal.voted[msg.sender] = true;
        emit Voted(msg.sender, proposalId, support);
    }

    function isBlacklisted(address user) public view returns (bool) {
        return blacklist[user];
    }

    function isCoOwner(address user) public view returns (bool) {
        for (uint256 i = 0; i < coOwners.length; i++) {
            if (coOwners[i] == user) {
                return true;
            }
        }
        return false;
    }

    function addCoOwner(address coOwner) public {
        require(msg.sender == contractOwner, "Only owner can add co-owner");
        require(!isCoOwner(coOwner), "Already a co-owner");
        coOwners.push(coOwner);
        emit CoOwnerAdded(coOwner);
    }

    function removeCoOwner(address coOwner) public {
        require(msg.sender == contractOwner, "Only owner can remove co-owner");

        for (uint256 i = 0; i < coOwners.length; i++) {
            if (coOwners[i] == coOwner) {
                coOwners[i] = coOwners[coOwners.length - 1];
                coOwners.pop();
                emit CoOwnerRemoved(coOwner);
                break;
            }
        }
    }

    function blacklistUser(address user) public onlyOwnerOrCoOwner {
        require(!blacklist[user], "User is already blacklisted");
        blacklist[user] = true;
        emit Blacklisted(user);
    }

    function unblacklistUser(address user) public onlyOwnerOrCoOwner {
        require(blacklist[user], "User is not blacklisted");
        blacklist[user] = false;
        emit Unblacklisted(user);
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

function withdraw(uint256 amount, address payable recipient) public onlyOwner {
    require(amount <= address(this).balance, "Insufficient balance in contract");
    require(recipient != address(0), "Invalid recipient address");

    
    recipient.transfer(amount);
}

function closeProposal(uint256 proposalId) public onlyOwnerOrCoOwner {
    require(proposalId < proposals.length, "Invalid proposal ID");
    Proposal storage proposal = proposals[proposalId];
    require(!proposal.executed, "Proposal already executed");
    require(block.timestamp < proposal.endTime, "Voting period has already ended");
    proposal.executed = true;
    emit ProposalExecuted(proposalId);
}
}
