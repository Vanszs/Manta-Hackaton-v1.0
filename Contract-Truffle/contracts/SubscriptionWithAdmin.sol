// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DAOLogic.sol";

contract SubscriptionWithAdmin {
    address public owner;
    mapping(address => bool) public coOwners;
    mapping(address => bool) public blacklist;
    uint256 public  ADMIN_FEE_PERCENTAGE = 10;
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

    function editfee(uint256 newfee) external onlyCoOwnerOrOwner{
        require(newfee <= 100 || newfee >= 1, "fee need between 1-100");
        ADMIN_FEE_PERCENTAGE = newfee;
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
