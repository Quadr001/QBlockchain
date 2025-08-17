// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Crowdfunding
 * @dev A simple crowdfunding smart contract where users can contribute Ether
 * to a campaign. The owner can withdraw the funds if the goal is met by the
 * deadline. Otherwise, contributors can reclaim their funds.
 */
contract Crowdfunding {
    // State Variables
    address payable public owner;
    uint public fundingGoal; // The target amount in Wei
    uint public deadline; // Unix timestamp for the end of the campaign
    uint public totalContributions;
    mapping(address => uint) public contributions;

    // Events
    event ContributionReceived(address indexed contributor, uint amount);
    event FundsWithdrawn(address indexed owner, uint amount);
    event RefundIssued(address indexed contributor, uint amount);

    /**
     * @dev Sets up the contract with a funding goal and a duration.
     * @param _fundingGoalInEther The target amount to raise, in Ether.
     * @param _durationInSeconds The duration of the campaign in seconds.
     */
    constructor(uint _fundingGoalInEther, uint _durationInSeconds) {
        // Ensure the funding goal and duration are realistic
        require(_fundingGoalInEther > 0, "Funding goal must be positive.");
        require(_durationInSeconds > 0, "Duration must be positive.");
        
        owner = payable(msg.sender);
        fundingGoal = _fundingGoalInEther * 1 ether; // Convert Ether to Wei
        deadline = block.timestamp + _durationInSeconds;
    }

    /**
     * @dev Allows users to contribute Ether to the campaign.
     * Reverts if the campaign is over or the contribution is zero.
     */
    function contribute() public payable {
        // 1. Validation Checks
        require(block.timestamp < deadline, "Campaign has ended.");
        require(msg.value > 0, "Contribution must be greater than zero.");

        // 2. Effects (Update State)
        contributions[msg.sender] += msg.value;
        totalContributions += msg.value;

        // 3. Interaction (Emit Event)
        emit ContributionReceived(msg.sender, msg.value);
    }

    /**
     * @dev Allows the owner to withdraw the entire contract balance if the
     * funding goal has been met after the deadline.
     */
    function withdrawFunds() public {
        // 1. Validation Checks
        require(msg.sender == owner, "Only the owner can withdraw funds.");
        require(block.timestamp >= deadline, "Campaign is still active.");
        require(totalContributions >= fundingGoal, "Funding goal not reached.");

        // 2. Effects (Emit Event before transfer for security)
        uint amount = address(this).balance;
        emit FundsWithdrawn(owner, amount);

        // 3. Interaction (Transfer Funds)
        // Using .call() is the recommended way to send Ether
        (bool sent, ) = owner.call{value: amount}("");
        require(sent, "Failed to send Ether.");
    }

    /**
     * @dev Allows contributors to reclaim their contribution if the funding
     * goal was NOT met by the deadline.
     */
    function reclaimContribution() public {
        // 1. Validation Checks
        require(block.timestamp >= deadline, "Campaign is still active.");
        require(totalContributions < fundingGoal, "Funding goal was reached; no refunds.");
        
        uint contributionAmount = contributions[msg.sender];
        require(contributionAmount > 0, "You have not contributed or have already reclaimed.");

        // 2. Effects (Update state *before* sending Ether to prevent re-entrancy)
        contributions[msg.sender] = 0; // Set to zero before transfer
        emit RefundIssued(msg.sender, contributionAmount);

        // 3. Interaction (Transfer Funds)
        (bool sent, ) = msg.sender.call{value: contributionAmount}("");
        require(sent, "Failed to send Ether.");
    }

    /**
     * @dev A helper function to check the contract's current balance.
     */
    function getContractBalance() public view returns (uint) {
        return address(this).balance;
    }
}
