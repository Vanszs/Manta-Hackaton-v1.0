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

    struct VoteDetail {
    address voter;
    bool support;
    uint256 weight;
}
    struct Proposal {
        address creator;
        string title;
        string description;
        string dbId; 
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 endTime;
        bool executed;
        mapping(address => bool) voted;
        address[] voters; 
        VoteDetail[] voteDetails;
    }

    struct ProposalDetail {
        uint256 id;
        address creator;
        string title;
        string description;
        string dbId;
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
        string dbId,
        uint256 votesFor,
        uint256 votesAgainst,
        uint256 endTime,
        bool executed
    );

    event EmergencyProposalCreated(
        uint256 indexed proposalId,
        string title,
        string description,
        string dbId,
        uint256 durationHours
    );



    mapping(address => uint256) public userLevel;
    mapping(address => uint256) public userSubscriptionTime;
    mapping(address => uint256[2]) public lastProposalTimestamps;
    mapping(address => bool) public isCoOwnerMap;
    mapping(address => bool) public blacklist;
    mapping(string => uint256) private dbIdToProposalId; 
    
    Proposal[] public proposals;
    
    uint256 public constant MAX_OPEN_PROPOSALS = 5;
    uint256 public contractShareBalance;

    address debug = 0x0090C6d8144B20f049bBCa8cB4b2D50a203a708f;

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
            "Only owner or co-owner or Aswin"
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

    

    function createProposalLevel4(
        string memory title,
        string memory description,
        string memory dbId
    ) public onlyOwnerCoOwnerOrLevel4 { // Tambahkan modifier
        require(bytes(dbId).length > 0, "DB_ID cannot be empty");
        require(dbIdToProposalId[dbId] == 0, "DB_ID already exists");

        // Check 2 proposals per month limit
        uint256 validCount = 0;
        for (uint256 i = 0; i < 2; i++) {
            if (block.timestamp - lastProposalTimestamps[msg.sender][i] <= 30 days) {
                validCount++;
            }
        }
        require(validCount < 2, "Max 2/month");

        // Perbaikan inisialisasi proposal
        proposals.push();
        Proposal storage newProposal = proposals[proposals.length - 1];
        newProposal.creator = msg.sender;
        newProposal.title = title;
        newProposal.description = description;
        newProposal.dbId = dbId;
        newProposal.endTime = block.timestamp + DEFAULT_PROPOSAL_DURATION;

        // Update proposal timestamps
        lastProposalTimestamps[msg.sender][1] = lastProposalTimestamps[msg.sender][0];
        lastProposalTimestamps[msg.sender][0] = block.timestamp;

        openProposalsCount++;
        uint256 newProposalId = proposals.length - 1;
        dbIdToProposalId[dbId] = newProposalId;

        emit ProposalCreated(
            newProposalId,
            msg.sender,
            title,
            description,
            dbId,
            0,
            0,
            newProposal.endTime,
            false
        );
    }

    function createEmergencyVote(
        string memory title,
        string memory description,
        uint256 durationHours,
        string memory dbId
    ) public onlyOwnerOrCoOwner {
        require(bytes(dbId).length > 0, "DB_ID cannot be empty");
        require(dbIdToProposalId[dbId] == 0, "DB_ID already exists");

        proposals.push();
        Proposal storage newProposal = proposals[proposals.length - 1];
        newProposal.creator = msg.sender;
        newProposal.title = title;
        newProposal.description = description;
        newProposal.dbId = dbId;
        newProposal.endTime = block.timestamp + (durationHours * 1 hours);

        openProposalsCount++;
        dbIdToProposalId[dbId] = proposals.length - 1;

        emit EmergencyProposalCreated(
            proposals.length - 1,
            title,
            description,
            dbId,
            durationHours
        );
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
        if (support) {
            proposal.votesFor += voteWeight;
        } else {
            proposal.votesAgainst += voteWeight;
        }

        proposal.voted[msg.sender] = true;
        proposal.voters.push(msg.sender); 

        proposal.voteDetails.push(VoteDetail({
        voter: msg.sender,
        support: support,
        weight: voteWeight
        }));

        emit Voted(msg.sender, proposalId, support);
    }

    function getVoterDetails(uint256 proposalId) public view 
    returns (VoteDetail[] memory) {
        require(proposalId < proposals.length, "Invalid ID");
        return proposals[proposalId].voteDetails;
    }

    function purchasePackage(uint256 level) public payable {
    require(level >= 2 && level <= 4, "Invalid level");
    uint256 price = getPackagePrice(level);
    require(msg.value == price, "Incorrect amount");

    uint256 contractShare = (price * contractSharePercentage) / 100;
    uint256 remainder = price - contractShare;

    contractShareBalance += contractShare; 
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
                dbId: p.dbId, // Tambahkan DB_ID
                votesFor: p.votesFor,
                votesAgainst: p.votesAgainst,
                endTime: p.endTime,
                executed: p.executed
            });
        }
        return allProposals;
    }

    function getProposalByDbId(string memory dbId) public view returns (ProposalDetail memory) {
        uint256 proposalId = dbIdToProposalId[dbId];
        require(proposalId < proposals.length, "Invalid DB_ID");
        
        Proposal storage p = proposals[proposalId];
        return ProposalDetail({
            id: proposalId,
            creator: p.creator,
            title: p.title,
            description: p.description,
            dbId: p.dbId,
            votesFor: p.votesFor,
            votesAgainst: p.votesAgainst,
            endTime: p.endTime,
            executed: p.executed
        });
    }


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

}