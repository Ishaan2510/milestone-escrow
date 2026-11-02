// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MilestoneEscrow} from "../src/MilestoneEscrow.sol";
import {ReentrantFreelancer} from "./mocks/ReentrantFreelancer.sol";

contract MilestoneEscrowTest is Test {
    MilestoneEscrow internal escrow;

    address internal client = address(0xC1); // deployer = owner = client
    address payable internal freelancer = payable(address(0xF1));
    address internal arbiter = address(0xA1);
    address internal stranger = address(0xBAD);

    uint256 internal constant DEPOSIT = 3 ether;
    uint256 internal constant COUNT = 3;
    uint256 internal constant DAYS = 30;

    // Redeclared so vm.expectEmit can match them
    event Submitted(uint256 index);
    event Paid(uint256 index, address to, uint256 amount);
    event Disputed(uint256 index);
    event Resolved(uint256 index, bool paidFreelancer);
    event Refunded(uint256 index, uint256 amount);
    event Deposited(address from, uint256 amount);

    function setUp() public {
        vm.deal(client, 100 ether);
        vm.prank(client);
        escrow = new MilestoneEscrow{value: DEPOSIT}(freelancer, arbiter, COUNT, DAYS);
    }

    // ---------------------------------------------------------------- helpers
    function _status(uint256 i) internal view returns (MilestoneEscrow.Status s) {
        (, s,) = escrow.getMilestone(i);
    }

    function _submit(uint256 i) internal {
        vm.prank(freelancer);
        escrow.submitMilestone(i);
    }

    // ---------------------------------------------------------------- constructor
    function test_Constructor_SetsPartiesAndSplit() public view {
        assertEq(escrow.owner(), client);
        assertEq(escrow.freelancer(), freelancer);
        assertEq(escrow.arbiter(), arbiter);
        assertEq(escrow.milestoneCount(), COUNT);
        assertEq(escrow.getBalance(), DEPOSIT);
        assertEq(escrow.projectDeadline(), block.timestamp + DAYS * 1 days);
        for (uint256 i = 0; i < COUNT; i++) {
            (uint256 amount, MilestoneEscrow.Status s, uint256 at) = escrow.getMilestone(i);
            assertEq(amount, 1 ether);
            assertEq(uint256(s), uint256(MilestoneEscrow.Status.Pending));
            assertEq(at, 0);
        }
    }

    function test_Constructor_LastMilestoneTakesRemainder() public {
        vm.prank(client);
        MilestoneEscrow e = new MilestoneEscrow{value: 10}(freelancer, arbiter, 3, DAYS);
        (uint256 a0,,) = e.getMilestone(0);
        (uint256 a2,,) = e.getMilestone(2);
        assertEq(a0, 3);
        assertEq(a2, 4); // 3 + remainder 1
    }

    function test_RevertWhen_NoDeposit() public {
        vm.prank(client);
        vm.expectRevert(bytes("Deposit required"));
        new MilestoneEscrow(freelancer, arbiter, COUNT, DAYS);
    }

    function test_RevertWhen_ZeroMilestones() public {
        vm.prank(client);
        vm.expectRevert(bytes("Need at least 1 milestone"));
        new MilestoneEscrow{value: 1 ether}(freelancer, arbiter, 0, DAYS);
    }

    function test_RevertWhen_ZeroAddress() public {
        vm.prank(client);
        vm.expectRevert(bytes("Zero address"));
        new MilestoneEscrow{value: 1 ether}(payable(address(0)), arbiter, COUNT, DAYS);
    }

    function test_RevertWhen_ClientIsFreelancer() public {
        vm.prank(client);
        vm.expectRevert(bytes("Client cannot be freelancer"));
        new MilestoneEscrow{value: 1 ether}(payable(client), arbiter, COUNT, DAYS);
    }

    // ---------------------------------------------------------------- happy path
    function test_SubmitThenApprove_PaysFreelancer() public {
        vm.expectEmit(true, true, true, true);
        emit Submitted(0);
        _submit(0);
        assertEq(uint256(_status(0)), uint256(MilestoneEscrow.Status.Submitted));

        uint256 before = freelancer.balance;
        vm.expectEmit(true, true, true, true);
        emit Paid(0, freelancer, 1 ether);
        vm.prank(client);
        escrow.approveMilestone(0);

        assertEq(freelancer.balance, before + 1 ether);
        assertEq(escrow.getBalance(), 2 ether);
        assertEq(escrow.reputation(freelancer), 1);
        assertEq(uint256(_status(0)), uint256(MilestoneEscrow.Status.Paid));
    }

    function test_FullProject_DrainsEscrowExactly() public {
        for (uint256 i = 0; i < COUNT; i++) {
            _submit(i);
            vm.prank(client);
            escrow.approveMilestone(i);
        }
        assertEq(escrow.getBalance(), 0);
        assertEq(freelancer.balance, DEPOSIT);
        assertEq(escrow.reputation(freelancer), COUNT);
    }

    // ---------------------------------------------------------------- access control
    function test_RevertWhen_NonFreelancerSubmits() public {
        vm.prank(stranger);
        vm.expectRevert(bytes("Only freelancer"));
        escrow.submitMilestone(0);
    }

    function test_RevertWhen_FreelancerApproves() public {
        _submit(1);
        vm.prank(freelancer);
        vm.expectRevert(bytes("Only client"));
        escrow.approveMilestone(1);
    }

    function test_RevertWhen_NonArbiterResolves() public {
        _submit(0);
        vm.prank(client);
        escrow.raiseDispute(0);
        vm.prank(client);
        vm.expectRevert(bytes("Only arbiter"));
        escrow.resolveDispute(0, false);
    }

    function test_RevertWhen_BadIndex() public {
        vm.prank(freelancer);
        vm.expectRevert(bytes("Bad milestone index"));
        escrow.submitMilestone(COUNT);
    }

    // ---------------------------------------------------------------- state rules
    function test_RevertWhen_ApproveNotSubmitted() public {
        vm.prank(client);
        vm.expectRevert(bytes("Not submitted"));
        escrow.approveMilestone(0);
    }

    function test_RevertWhen_PaidTwice() public {
        _submit(0);
        vm.prank(client);
        escrow.approveMilestone(0);
        vm.prank(client);
        vm.expectRevert(bytes("Not submitted"));
        escrow.approveMilestone(0);
    }

    function test_RevertWhen_SubmitTwice() public {
        _submit(0);
        vm.prank(freelancer);
        vm.expectRevert(bytes("Not pending"));
        escrow.submitMilestone(0);
    }

    function test_RevertWhen_SubmitAfterDeadline() public {
        vm.warp(block.timestamp + DAYS * 1 days + 1);
        vm.prank(freelancer);
        vm.expectRevert(bytes("Project deadline passed"));
        escrow.submitMilestone(0);
    }

    // ---------------------------------------------------------------- timeout
    function test_ClaimAfterTimeout() public {
        _submit(1);
        assertEq(escrow.timeLeft(1), 7 days);

        vm.prank(freelancer);
        vm.expectRevert(bytes("Timeout not reached"));
        escrow.claimAfterTimeout(1);

        vm.warp(block.timestamp + 7 days);
        assertEq(escrow.timeLeft(1), 0);
        vm.prank(freelancer);
        escrow.claimAfterTimeout(1);
        assertEq(freelancer.balance, 1 ether);
    }

    function test_RevertWhen_TimeLeftNotSubmitted() public {
        vm.expectRevert(bytes("Not submitted"));
        escrow.timeLeft(0);
    }

    // ---------------------------------------------------------------- disputes
    function test_Dispute_ArbiterPaysFreelancer() public {
        _submit(2);
        vm.prank(freelancer);
        escrow.raiseDispute(2);
        assertEq(uint256(_status(2)), uint256(MilestoneEscrow.Status.Disputed));

        vm.expectEmit(true, true, true, true);
        emit Resolved(2, true);
        vm.prank(arbiter);
        escrow.resolveDispute(2, true);
        assertEq(freelancer.balance, 1 ether);
        assertEq(uint256(_status(2)), uint256(MilestoneEscrow.Status.Paid));
    }

    function test_Dispute_ArbiterRefundsClient() public {
        _submit(2);
        vm.prank(client);
        escrow.raiseDispute(2);
        uint256 before = client.balance;
        vm.prank(arbiter);
        escrow.resolveDispute(2, false);
        assertEq(client.balance, before + 1 ether);
        assertEq(escrow.reputation(freelancer), 0);
        assertEq(uint256(_status(2)), uint256(MilestoneEscrow.Status.Refunded));
    }

    function test_RevertWhen_StrangerDisputes() public {
        _submit(0);
        vm.prank(stranger);
        vm.expectRevert(bytes("Not a party"));
        escrow.raiseDispute(0);
    }

    function test_DisputeBlocksTimeoutClaim() public {
        _submit(0);
        vm.prank(client);
        escrow.raiseDispute(0);
        vm.warp(block.timestamp + 7 days);
        vm.prank(freelancer);
        vm.expectRevert(bytes("Not submitted"));
        escrow.claimAfterTimeout(0);
    }

    // ---------------------------------------------------------------- refunds
    function test_RefundPendingAfterDeadline() public {
        vm.prank(client);
        vm.expectRevert(bytes("Deadline not reached"));
        escrow.refundPending(0);

        vm.warp(block.timestamp + DAYS * 1 days + 1);
        uint256 before = client.balance;
        vm.expectEmit(true, true, true, true);
        emit Refunded(0, 1 ether);
        vm.prank(client);
        escrow.refundPending(0);
        assertEq(client.balance, before + 1 ether);
    }

    function test_RevertWhen_RefundSubmittedMilestone() public {
        _submit(0);
        vm.warp(block.timestamp + DAYS * 1 days + 1);
        vm.prank(client);
        vm.expectRevert(bytes("Not pending"));
        escrow.refundPending(0);
    }

    // ---------------------------------------------------------------- receive()
    function test_TopUpAddsToLastMilestone() public {
        vm.prank(client);
        (bool ok,) = address(escrow).call{value: 0.5 ether}("");
        assertTrue(ok);
        (uint256 last,,) = escrow.getMilestone(COUNT - 1);
        assertEq(last, 1.5 ether);
        assertEq(escrow.getBalance(), 3.5 ether);
    }

    function test_RevertWhen_StrangerTopsUp() public {
        vm.deal(stranger, 1 ether);
        vm.prank(stranger);
        (bool ok,) = address(escrow).call{value: 1 ether}("");
        assertFalse(ok); // reverted with "Only client"
    }

    // ---------------------------------------------------------------- security: re-entrancy
    function test_ReentrancyCannotDoublePay() public {
        ReentrantFreelancer attacker = new ReentrantFreelancer();
        vm.prank(client);
        MilestoneEscrow e = new MilestoneEscrow{value: 2 ether}(payable(address(attacker)), arbiter, 2, DAYS);
        attacker.setTarget(e);

        attacker.submit(0);
        vm.warp(block.timestamp + 7 days);
        attacker.claim(0); // inside receive() it tries to claim milestone 0 again

        assertTrue(attacker.reentryAttempted());
        assertFalse(attacker.reentrySucceeded());
        assertEq(address(attacker).balance, 1 ether); // paid exactly once
        assertEq(e.getBalance(), 1 ether);
    }

    // ---------------------------------------------------------------- fuzz
    /// For any deposit and milestone count, the split never loses or creates wei.
    function testFuzz_SplitConservesDeposit(uint96 deposit, uint8 count) public {
        vm.assume(deposit > 0 && count > 0 && count <= 50);
        vm.deal(client, deposit);
        vm.prank(client);
        MilestoneEscrow e = new MilestoneEscrow{value: deposit}(freelancer, arbiter, count, DAYS);
        uint256 sum;
        for (uint256 i = 0; i < count; i++) {
            (uint256 a,,) = e.getMilestone(i);
            sum += a;
        }
        assertEq(sum, deposit);
    }

    /// Paying some milestones and refunding the rest always empties the escrow exactly.
    function testFuzz_EveryWeiEndsWithAParty(uint96 deposit, uint8 count, uint256 payMask) public {
        vm.assume(deposit > 0 && count > 0 && count <= 16);
        vm.deal(client, deposit);
        vm.prank(client);
        MilestoneEscrow e = new MilestoneEscrow{value: deposit}(freelancer, arbiter, count, DAYS);
        uint256 clientBefore = client.balance;
        uint256 freelancerBefore = freelancer.balance;

        for (uint256 i = 0; i < count; i++) {
            if ((payMask >> i) & 1 == 1) {
                vm.prank(freelancer);
                e.submitMilestone(i);
                vm.prank(client);
                e.approveMilestone(i);
            }
        }
        vm.warp(block.timestamp + DAYS * 1 days + 1);
        for (uint256 i = 0; i < count; i++) {
            if ((payMask >> i) & 1 == 0) {
                vm.prank(client);
                e.refundPending(i);
            }
        }
        assertEq(e.getBalance(), 0);
        assertEq((client.balance - clientBefore) + (freelancer.balance - freelancerBefore), deposit);
    }
}
