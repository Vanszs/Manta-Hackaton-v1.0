// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DAOLogic.sol";

contract SubscriptionWithAdmin {
    address public owner;
    mapping(address => bool) public coOwners;
    mapping(address => bool) public blacklist;
    uint256 public ADMIN_FEE_PERCENTAGE = 10;
    uint256 public adminFeeETH;
    bool public isActive = true;

    struct User {
        uint8 level;
        uint256 subscriptionEnd;
    }

    mapping(address => User) public users;

    event Subscribed(address indexed user, uint8 level, uint256 endTime);
    event FeeCollected(address indexed user, uint256 feeAmount);
    event UserBlacklisted(address indexed user);
    event CoOwnerAdded(address indexed coOwner);
    event CoOwnerRemoved(address indexed coOwner);
    event ContractDeactivated();
    event ProposalCreated(uint256 indexed proposalId, string description);
    event ProposalVoted(uint256 indexed proposalId, bool support, uint8 level);
    event ProposalClosed(uint256 indexed proposalId, bool result);
    event MaxActiveProposalsUpdated(uint256 oldLimit, uint256 newLimit);

    DAOLogic public daoLogic;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can execute this");
        _;
    }

    modifier onlyCoOwnerOrOwner() {
        require(msg.sender == owner || coOwners[msg.sender], "Not authorized");
        _;
    }

    modifier isContractActive() {
        require(isActive, "Contract is not active");
        _;
    }

    constructor() {
        owner = msg.sender;
        daoLogic = new DAOLogic(address(this));
    }

    function subscribe(uint8 level) external payable isContractActive {
        require(!blacklist[msg.sender], "User is blacklisted");
        require(level >= 1 && level <= 3, "Invalid subscription level");

        uint256 cost = level == 1 ? 0.1 ether : level == 2 ? 0.2 ether : 0.3 ether;
        uint256 adminFee = (cost * ADMIN_FEE_PERCENTAGE) / 100;
        uint256 totalCost = cost + adminFee;

        require(msg.value == totalCost, "Incorrect payment amount");

        adminFeeETH += adminFee;

        if (users[msg.sender].subscriptionEnd > block.timestamp) {
            users[msg.sender].subscriptionEnd += 30 days;
        } else {
            users[msg.sender] = User({
                level: level,
                subscriptionEnd: block.timestamp + 30 days
            });
        }

        emit Subscribed(msg.sender, level, users[msg.sender].subscriptionEnd);
        emit FeeCollected(msg.sender, adminFee);
    }

    function createProposal(string calldata description) external {
        uint8 level = users[msg.sender].level;
        require(level == 3, "Only Level 3 users can create proposals");
        daoLogic.createProposal(description, level);
        emit ProposalCreated(daoLogic.nextProposalId() - 1, description);
    }

    function voteOnProposal(uint256 proposalId, bool support) external {
        uint8 level = users[msg.sender].level;
        require(level > 0, "You must have an active subscription to vote");
        daoLogic.vote(proposalId, support, level);
        emit ProposalVoted(proposalId, support, level);
    }

    function closeProposal(uint256 proposalId) external onlyOwner {
        daoLogic.closeProposal(proposalId);
        emit ProposalClosed(proposalId, true);
    }

    function emergencyCloseProposal(uint256 proposalId) external onlyOwner {
        daoLogic.emergencyCloseProposal(proposalId);
    }

    function updateMaxActiveProposals(uint256 newLimit) external onlyCoOwnerOrOwner {
        require(newLimit >= 1, "Must allow at least 1 active proposal");

        uint256 oldLimit = daoLogic.MAX_ACTIVE_PROPOSALS(); // Ambil nilai lama dari DAOLogic
        daoLogic.updateMaxActiveProposals(newLimit); // Perbarui nilai di DAOLogic
        emit MaxActiveProposalsUpdated(oldLimit, newLimit); 
    }

    function withdrawAdminFee() external onlyOwner {
        require(adminFeeETH > 0, "No admin fee to withdraw");
        uint256 amount = adminFeeETH;
        adminFeeETH = 0;
        payable(owner).transfer(amount);
    }

    function deactivateContract() external onlyCoOwnerOrOwner {
        isActive = false;
        emit ContractDeactivated();
    }

    function editFee(uint256 newFee) external onlyCoOwnerOrOwner {
        require(newFee <= 100 && newFee >= 1, "Fee must be between 1-100");
        ADMIN_FEE_PERCENTAGE = newFee;
    }

    function addBlacklist(address user) external onlyCoOwnerOrOwner {
        blacklist[user] = true;
        emit UserBlacklisted(user);
    }

    function removeBlacklist(address user) external onlyCoOwnerOrOwner {
        blacklist[user] = false;
    }

    function addCoOwner(address coOwner) external onlyOwner {
        coOwners[coOwner] = true;
        emit CoOwnerAdded(coOwner);
    }

    function removeCoOwner(address coOwner) external onlyOwner {
        coOwners[coOwner] = false;
        emit CoOwnerRemoved(coOwner);
    }

    receive() external payable {}
    fallback() external payable {}
}
