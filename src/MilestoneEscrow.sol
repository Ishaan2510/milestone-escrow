// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20; // CONCEPT: compiler version pragma (0.8.x reverts on overflow automatically)

/// @title  Ownable
/// @notice Base contract that remembers who deployed it.
/// CONCEPT: inheritance -- MilestoneEscrow "is Ownable" and reuses this code.
contract Ownable {
    address public owner; // CONCEPT: state variable, stored permanently on-chain

    constructor() {
        owner = msg.sender; // CONCEPT: msg.sender = the account that sent this transaction (the deployer)
    }

    // CONCEPT: modifier -- a reusable check that runs before the function body ("_;")
    modifier onlyOwner() {
        require(msg.sender == owner, "Only client"); // CONCEPT: require reverts the whole tx if false
        _;
    }
}

/// @title  PayMath
/// @notice Splits a total amount into n milestone payments.
/// CONCEPT: library -- reusable code with no storage of its own.
library PayMath {
    // CONCEPT: pure -- reads no state and writes no state, only computes from its inputs
    function splitEqual(uint256 total, uint256 n) internal pure returns (uint256[] memory parts) {
        parts = new uint256[](n); // CONCEPT: memory array, exists only during this call
        uint256 share = total / n; // integer division rounds down
        for (uint256 i = 0; i < n; i++) {
            parts[i] = share;
        }
        parts[n - 1] += total % n; // last milestone takes the remainder, so no wei is lost
    }
}

/// @title  MilestoneEscrow
/// @notice Client locks payment; freelancer is paid milestone by milestone.
contract MilestoneEscrow is Ownable {
    // ------------------------------------------------------------------ types
    // CONCEPT: enum -- a named list of states (stored as 0,1,2,3,4)
    enum Status {
        Pending, // 0: waiting for the freelancer
        Submitted, // 1: freelancer says it is done
        Paid, // 2: freelancer has been paid
        Refunded, // 3: money returned to the client
        Disputed // 4: waiting for the arbiter
    }

    // CONCEPT: struct -- groups related data into one custom type
    struct Milestone {
        uint256 amount; // wei paid for this milestone
        Status status; // current state
        uint256 submittedAt; // time of submission (0 if never submitted)
    }

    // ------------------------------------------------------------------ state
    address payable public immutable freelancer; // CONCEPT: immutable -- set once in constructor, then fixed
    address public immutable arbiter; // neutral third party for disputes
    uint256 public immutable projectDeadline; // after this, undelivered milestones can be refunded
    uint256 public constant TIMEOUT = 7 days; // CONCEPT: constant -- fixed at compile time

    Milestone[] public milestones; // CONCEPT: dynamic array of structs
    mapping(address => uint256) public reputation; // CONCEPT: mapping -- address => paid milestones count

    // ------------------------------------------------------------------ events
    // CONCEPT: events -- cheap logs that front ends and explorers can read
    event Submitted(uint256 index);
    event Paid(uint256 index, address to, uint256 amount);
    event Disputed(uint256 index);
    event Resolved(uint256 index, bool paidFreelancer);
    event Refunded(uint256 index, uint256 amount);
    event Deposited(address from, uint256 amount);

    // ------------------------------------------------------------------ modifiers
    modifier onlyFreelancer() {
        require(msg.sender == freelancer, "Only freelancer");
        _;
    }

    modifier onlyArbiter() {
        require(msg.sender == arbiter, "Only arbiter");
        _;
    }

    modifier validIndex(uint256 i) {
        require(i < milestones.length, "Bad milestone index");
        _;
    }

    // ------------------------------------------------------------------ constructor
    // CONCEPT: constructor runs ONCE at deployment; payable lets it receive the deposit
    constructor(address payable _freelancer, address _arbiter, uint256 _milestoneCount, uint256 _durationDays)
        payable
    {
        require(msg.value > 0, "Deposit required"); // CONCEPT: msg.value = wei sent with this tx
        require(_milestoneCount > 0, "Need at least 1 milestone");
        require(_freelancer != address(0) && _arbiter != address(0), "Zero address");
        require(_freelancer != msg.sender, "Client cannot be freelancer");

        freelancer = _freelancer;
        arbiter = _arbiter;
        projectDeadline = block.timestamp + _durationDays * 1 days; // CONCEPT: block.timestamp = current block time

        uint256[] memory parts = PayMath.splitEqual(msg.value, _milestoneCount); // CONCEPT: library call
        for (uint256 i = 0; i < _milestoneCount; i++) {
            milestones.push(Milestone(parts[i], Status.Pending, 0));
        }
        emit Deposited(msg.sender, msg.value); // CONCEPT: emit an event
    }

    // ------------------------------------------------------------------ freelancer actions
    /// Freelancer marks milestone i as done.
    function submitMilestone(uint256 i) external onlyFreelancer validIndex(i) {
        Milestone storage m = milestones[i]; // CONCEPT: storage pointer -- edits the real on-chain data
        require(m.status == Status.Pending, "Not pending");
        require(block.timestamp <= projectDeadline, "Project deadline passed");
        m.status = Status.Submitted;
        m.submittedAt = block.timestamp;
        emit Submitted(i);
    }

    /// Freelancer gets paid if the client stays silent for TIMEOUT after submission.
    function claimAfterTimeout(uint256 i) external onlyFreelancer validIndex(i) {
        Milestone storage m = milestones[i];
        require(m.status == Status.Submitted, "Not submitted");
        require(block.timestamp >= m.submittedAt + TIMEOUT, "Timeout not reached");
        _release(i);
    }

    // ------------------------------------------------------------------ client actions
    /// Client accepts the work; contract pays the freelancer.
    function approveMilestone(uint256 i) external onlyOwner validIndex(i) {
        require(milestones[i].status == Status.Submitted, "Not submitted");
        _release(i);
    }

    /// Client takes back money for a milestone never delivered by the deadline.
    function refundPending(uint256 i) external onlyOwner validIndex(i) {
        require(milestones[i].status == Status.Pending, "Not pending");
        require(block.timestamp > projectDeadline, "Deadline not reached");
        _refund(i);
    }

    /// Client tops up the escrow; the extra is added to the last milestone as a bonus.
    // CONCEPT: receive() runs when plain ether is sent to the contract with no function call
    receive() external payable onlyOwner {
        Milestone storage last = milestones[milestones.length - 1];
        require(last.status == Status.Pending, "Last milestone already closed");
        last.amount += msg.value;
        emit Deposited(msg.sender, msg.value);
    }

    // ------------------------------------------------------------------ disputes
    /// Either party can freeze a submitted milestone for the arbiter.
    function raiseDispute(uint256 i) external validIndex(i) {
        require(msg.sender == owner || msg.sender == freelancer, "Not a party");
        require(milestones[i].status == Status.Submitted, "Not submitted");
        milestones[i].status = Status.Disputed;
        emit Disputed(i);
    }

    /// Arbiter decides: pay the freelancer (true) or refund the client (false).
    function resolveDispute(uint256 i, bool payFreelancer) external onlyArbiter validIndex(i) {
        require(milestones[i].status == Status.Disputed, "Not disputed");
        emit Resolved(i, payFreelancer);
        if (payFreelancer) {
            _release(i);
        } else {
            _refund(i);
        }
    }

    // ------------------------------------------------------------------ views (free to call)
    // CONCEPT: view -- reads state but never changes it; no gas when called from outside
    function getMilestone(uint256 i)
        external
        view
        validIndex(i)
        returns (uint256 amount, Status status, uint256 submittedAt)
    {
        Milestone memory m = milestones[i]; // CONCEPT: memory copy -- read-only snapshot
        return (m.amount, m.status, m.submittedAt);
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance; // ether currently locked in the contract
    }

    function milestoneCount() external view returns (uint256) {
        return milestones.length;
    }

    /// Seconds until the freelancer may call claimAfterTimeout (0 = can claim now).
    function timeLeft(uint256 i) external view validIndex(i) returns (uint256) {
        Milestone memory m = milestones[i];
        require(m.status == Status.Submitted, "Not submitted");
        uint256 unlockAt = m.submittedAt + TIMEOUT;
        if (block.timestamp >= unlockAt) return 0;
        return unlockAt - block.timestamp;
    }

    // ------------------------------------------------------------------ internal money movement
    // CONCEPT: checks-effects-interactions -- change state FIRST, send ether LAST.
    // If the receiver tries to call back in (re-entrancy), the status is already final,
    // so every "require(status == ...)" check fails and it cannot be paid twice.

    function _release(uint256 i) private {
        Milestone storage m = milestones[i];
        m.status = Status.Paid; // EFFECT
        reputation[freelancer] += 1; // EFFECT
        emit Paid(i, freelancer, m.amount);
        _send(freelancer, m.amount); // INTERACTION (last)
    }

    function _refund(uint256 i) private {
        Milestone storage m = milestones[i];
        m.status = Status.Refunded; // EFFECT
        emit Refunded(i, m.amount);
        _send(payable(owner), m.amount); // INTERACTION (last)
    }

    /// The ONLY place ether leaves this contract.
    function _send(address payable to, uint256 amount) private {
        (bool ok,) = to.call{value: amount}(""); // CONCEPT: low-level call forwards ether (recommended over transfer)
        require(ok, "Ether transfer failed");
    }
}
