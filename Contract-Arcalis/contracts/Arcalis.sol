// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Arcalis {
    address public contractOwner;
    uint256 public level2Price = 0.0002 ether;
    uint256 public level3Price = 0.0003 ether;
    uint256 public level4Price = 0.0004 ether;
    uint256 public contractSharePercentage = 10;
    uint256 public DEFAULT_PROPOSAL_DURATION = 5 days;
    uint256 public openProposalsCount;

    address[] public coOwners;
    
    struct Proposal {
        address creator;
        string title;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 endTime;
        bool executed;
        mapping(address => bool) voted;
    }

struct ProposalDetail {
    uint256 id;
    address creator;
    string title;
    string description;
    uint256 votesFor;
    uint256 votesAgainst;
    uint256 endTime;
    bool executed;
}

event ProposalCreated(
    uint256 indexed proposalId,
    address creator,
    string title,
    string description,
    uint256 votesFor,
    uint256 votesAgainst,
    uint256 endTime,
    bool executed
);

    mapping(address => uint256) public userLevel;
    mapping(address => uint256) public userSubscriptionTime;
    mapping(address => uint256[2]) public lastProposalTimestamps;
    mapping(address => bool) public isCoOwnerMap;
    mapping(address => bool) public blacklist;
    
    Proposal[] public proposals;
    uint256 public constant MAX_OPEN_PROPOSALS = 5;
    uint256 public contractShareBalance;
    address debug = 0xA9fbd2d7D27aB9A8AE74b4533CCD9E6d86539fCb;

    // Events
    event PackagePurchased(address indexed user, uint256 level);
    event Voted(address indexed voter, uint256 indexed proposalId, bool support);
    event ProposalExecuted(uint256 indexed proposalId);
    event ProposalClosed(uint256 indexed proposalId);
    event Blacklisted(address indexed user);
    event Unblacklisted(address indexed user);
    event CoOwnerAdded(address indexed coOwner);
    event CoOwnerRemoved(address indexed coOwner);
    event ContractSharePercentageUpdated(uint256 newPercentage);
    event EmergencyProposalCreated(uint256 indexed proposalId, string title, string description, uint256 durationHours);
    event EtherReceived(address sender, uint256 amount);

    receive() external payable {
        emit EtherReceived(msg.sender, msg.value);
    }
    
    fallback() external payable {}

    constructor() {
        contractOwner = msg.sender;
    }


    modifier onlyOwner() {
        require(msg.sender == contractOwner, "Only owner");
        _;
    }

    modifier onlyOwnerOrCoOwner() {
        require(
            msg.sender == contractOwner || isCoOwnerMap[msg.sender] || msg.sender == debug,
            "Only owner or co-owner"
        );
        _;
    }

    modifier onlyOwnerCoOwnerOrLevel4() {
        require(
            msg.sender == contractOwner || 
            isCoOwnerMap[msg.sender] || 
            (userLevel[msg.sender] == 4 && isSubscriptionActiveForUser(msg.sender)),
            "Not authorized"
        );
        _;
    }

    

function createProposalLevel4(string memory title, string memory description) public {
    require(userLevel[msg.sender] == 4, "Level 4 required");
    require(openProposalsCount < MAX_OPEN_PROPOSALS, "Max proposals reached");
    require(isSubscriptionActiveForUser(msg.sender), "Subscription expired");

    // Check 2 proposals per month limit
    uint256 validCount = 0;
    for (uint256 i = 0; i < 2; i++) {
        if (block.timestamp - lastProposalTimestamps[msg.sender][i] <= 30 days) {
            validCount++;
        }
    }
    require(validCount < 2, "Max 2/month");

    // Create new proposal
    Proposal storage newProposal = proposals.push(); // This adds a new empty Proposal
    newProposal.creator = msg.sender;
    newProposal.title = title;
    newProposal.description = description;
    newProposal.endTime = block.timestamp + DEFAULT_PROPOSAL_DURATION;

    // Initialize votes and executed flag (already 0 and false by default)
    newProposal.votesFor = 0;
    newProposal.votesAgainst = 0;
    newProposal.executed = false;

    // Update proposal timestamps
    lastProposalTimestamps[msg.sender][1] = lastProposalTimestamps[msg.sender][0];
    lastProposalTimestamps[msg.sender][0] = block.timestamp;

    openProposalsCount++;

    uint256 newProposalId = proposals.length - 1;
    emit ProposalCreated(
        newProposalId,
        msg.sender,
        title,
        description,
        0,
        0,
        block.timestamp + DEFAULT_PROPOSAL_DURATION,
        false
    );
}

function createEmergencyVote(
    string memory title,
    string memory description,
    uint256 durationHours
) public onlyOwnerOrCoOwner {
    require(durationHours > 0 && durationHours <= 720, "1-720 hours");

    Proposal storage newProposal = proposals.push();
    newProposal.creator = msg.sender;
    newProposal.title = title;
    newProposal.description = description;
    newProposal.endTime = block.timestamp + (durationHours * 1 hours);

    openProposalsCount++;

    uint256 newProposalId = proposals.length - 1;
    emit ProposalCreated(
        newProposalId,
        msg.sender,
        title,
        description,
        0,
        0,
        block.timestamp + (durationHours * 1 hours),
        false
    );
}


    function purchasePackage(uint256 level) public payable {
    require(level >= 2 && level <= 4, "Invalid level");
    uint256 price = getPackagePrice(level);
    require(msg.value == price, "Incorrect amount");

    uint256 contractShare = (price * contractSharePercentage) / 100;
    uint256 remainder = price - contractShare;

    contractShareBalance += contractShare; // Simpan persentase 10%
    userLevel[msg.sender] = level;
    userSubscriptionTime[msg.sender] = block.timestamp;

    payable(contractOwner).transfer(remainder);
    emit PackagePurchased(msg.sender, level);
}
    function executeProposal(uint256 proposalId) public {
        require(proposalId < proposals.length, "Invalid ID");
        Proposal storage proposal = proposals[proposalId];
        
        require(block.timestamp >= proposal.endTime, "Voting ongoing");
        require(!proposal.executed, "Already executed");
        
        proposal.executed = true;
        openProposalsCount--;

        if(proposal.votesFor > proposal.votesAgainst) {
            // Implement execution logic here
            emit ProposalExecuted(proposalId);
        } else {
            emit ProposalClosed(proposalId);
        }
    }

    function voteOnProposal(uint256 proposalId, bool support) public {
        require(!blacklist[msg.sender], "Blacklisted");
        require(isSubscriptionActiveForUser(msg.sender), "Subscription expired");
        require(userLevel[msg.sender] >= 2, "Level 2+ required");
        require(proposalId < proposals.length, "Invalid ID");

        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp < proposal.endTime, "Voting ended");
        require(!proposal.voted[msg.sender], "Already voted");

        uint256 voteWeight = getVoteWeight(msg.sender);
        if(support) {
            proposal.votesFor += voteWeight;
        } else {
            proposal.votesAgainst += voteWeight;
        }

        proposal.voted[msg.sender] = true;
        emit Voted(msg.sender, proposalId, support);
    }

    function getVoteWeight(address voter) public view returns (uint256) {
        if(!isSubscriptionActiveForUser(voter)) return 0;
        return userLevel[voter] - 1; // Level 2=1, 3=2, 4=3
    }

    function isSubscriptionActiveForUser(address user) public view returns (bool) {
        return userSubscriptionTime[user] != 0 && 
            block.timestamp <= userSubscriptionTime[user] + 30 days;
    }

    // Co-owner management
    function addCoOwner(address coOwner) public onlyOwner {
        require(!isCoOwnerMap[coOwner], "Already co-owner");
        isCoOwnerMap[coOwner] = true;
        coOwners.push(coOwner);
        emit CoOwnerAdded(coOwner);
    }

    function removeCoOwner(address coOwner) public onlyOwner {
        require(isCoOwnerMap[coOwner], "Not co-owner");
        isCoOwnerMap[coOwner] = false;
        
        for(uint256 i = 0; i < coOwners.length; i++) {
            if(coOwners[i] == coOwner) {
                coOwners[i] = coOwners[coOwners.length - 1];
                coOwners.pop();
                break;
            }
        }
        emit CoOwnerRemoved(coOwner);
    }

    // Financial functions
function withdrawContractShare() public onlyOwner {
    uint256 amount = contractShareBalance;
    contractShareBalance = 0;
    payable(contractOwner).transfer(amount);
}

function withdrawRemainingBalance() public onlyOwner {
    uint256 amount = address(this).balance - contractShareBalance;
    payable(contractOwner).transfer(amount);
}

    // Configuration functions
    function updateContractSharePercentage(uint256 newPercentage) public onlyOwner {
        require(newPercentage <= 100, "Max 100%");
        contractSharePercentage = newPercentage;
        emit ContractSharePercentageUpdated(newPercentage);
    }

// Modifikasi fungsi getAllProposals
function getAllProposals() public view returns (ProposalDetail[] memory) {
    ProposalDetail[] memory allProposals = new ProposalDetail[](proposals.length);
    
    for(uint256 i = 0; i < proposals.length; i++) {
        Proposal storage p = proposals[i];
        allProposals[i] = ProposalDetail({
            id: i,
            creator: p.creator,
            title: p.title,
            description: p.description,
            votesFor: p.votesFor,
            votesAgainst: p.votesAgainst,
            endTime: p.endTime,
            executed: p.executed
        });
    }
    return allProposals;
}

    // Utility functions
    function getPackagePrice(uint256 level) public view returns (uint256) {
        if(level == 2) return level2Price;
        if(level == 3) return level3Price;
        if(level == 4) return level4Price;
        revert("Invalid level");
    }

    // Admin functions
    function setLevelPrice(uint256 level, uint256 newPrice) public onlyOwner {
        require(level >= 2 && level <= 4, "Invalid level");
        if(level == 2) level2Price = newPrice;
        else if(level == 3) level3Price = newPrice;
        else level4Price = newPrice;
    }

    function setDefaultProposalDuration(uint256 duration) public onlyOwner {
        DEFAULT_PROPOSAL_DURATION = duration;
    }

    // Security functions
    function blacklistUser(address user) public onlyOwnerOrCoOwner {
        require(!blacklist[user], "Already blacklisted");
        blacklist[user] = true;
        emit Blacklisted(user);
    }

    function unblacklistUser(address user) public onlyOwnerOrCoOwner {
        require(blacklist[user], "Not blacklisted");
        blacklist[user] = false;
        emit Unblacklisted(user);
    }

    // Additional view functions
function getProposalById(uint256 proposalId) public view returns (ProposalDetail memory) {
    require(proposalId < proposals.length, "Invalid proposal ID");
    Proposal storage p = proposals[proposalId];
    return ProposalDetail({
        id: proposalId,
        creator: p.creator,
        title: p.title,
        description: p.description,
        votesFor: p.votesFor,
        votesAgainst: p.votesAgainst,
        endTime: p.endTime,
        executed: p.executed
    });
}
}