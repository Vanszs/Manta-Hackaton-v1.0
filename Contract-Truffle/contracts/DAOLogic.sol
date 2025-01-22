// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract DAOLogic {
    address public subscriptionContract;

    struct Proposal {
        uint256 id;
        string description;
        uint256 votesFor;
        uint256 votesAgainst;
        address proposer;
        bool open;
        uint256 deadline;
    }

    uint256 public nextProposalId;
    uint256 public activeProposals;
    uint256 public  MAX_ACTIVE_PROPOSALS = 10;

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(address => uint256) public userActiveProposals;

    event ProposalCreated(uint256 indexed id, address indexed proposer, string description, uint256 deadline);
    event Voted(uint256 indexed id, address indexed voter, uint256 weight, bool support);
    event ProposalClosed(uint256 indexed id, bool result);

    modifier onlySubscriptionContract() {
        require(msg.sender == subscriptionContract, "Unauthorized");
        _;
    }

    constructor(address _subscriptionContract) {
        subscriptionContract = _subscriptionContract;
    }

    function createProposal(string calldata description, uint8 level) external onlySubscriptionContract {
        require(level == 3, "Only Level 3 users can propose");
        require(activeProposals < MAX_ACTIVE_PROPOSALS, "Max active proposals reached");
        require(userActiveProposals[msg.sender] == 0, "You already have an active proposal");

        uint256 deadline = block.timestamp + 30 days;

        proposals[nextProposalId] = Proposal({
            id: nextProposalId,
            description: description,
            votesFor: 0,
            votesAgainst: 0,
            proposer: msg.sender,
            open: true,
            deadline: deadline
        });

        userActiveProposals[msg.sender] = nextProposalId;
        activeProposals++;

        emit ProposalCreated(nextProposalId, msg.sender, description, deadline);
        nextProposalId++;
    }

    function vote(uint256 proposalId, bool support, uint8 level) external onlySubscriptionContract {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.open, "Proposal is closed");
        require(block.timestamp <= proposal.deadline, "Proposal has expired");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        uint256 weight = level;
        if (support) {
            proposal.votesFor += weight;
        } else {
            proposal.votesAgainst += weight;
        }

        hasVoted[proposalId][msg.sender] = true;
        emit Voted(proposalId, msg.sender, weight, support);
    }

    function closeProposal(uint256 proposalId) external onlySubscriptionContract {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.open, "Proposal is already closed");
        require(block.timestamp > proposal.deadline, "Proposal deadline not reached");

        proposal.open = false;
        activeProposals--;
        delete userActiveProposals[proposal.proposer];

        bool result = proposal.votesFor > proposal.votesAgainst;
        emit ProposalClosed(proposalId, result);
    }

    function getProposalStatus(uint256 proposalId)
        external
        view
        returns (bool open, bool result, uint256 votesFor, uint256 votesAgainst)
    {
        Proposal memory proposal = proposals[proposalId];
        if (block.timestamp <= proposal.deadline) {
            return (proposal.open, false, proposal.votesFor, proposal.votesAgainst); 
        }

        return (false, proposal.votesFor > proposal.votesAgainst, proposal.votesFor, proposal.votesAgainst); 
    }

    function deleteProposal(uint256 proposalId) external onlySubscriptionContract {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.open, "Proposal is still open");

        delete proposals[proposalId];
    }
        function emergencyCloseProposal(uint256 proposalId) external onlySubscriptionContract {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.open, "Proposal is already closed");

        proposal.open = false;
        activeProposals--;

        emit ProposalClosed(proposalId, false);
    }

    function updateMaxActiveProposals(uint256 newLimit) external onlySubscriptionContract {
        require(newLimit >= 1, "Must allow at least 1 active proposal");
        MAX_ACTIVE_PROPOSALS = newLimit;
    }

}
