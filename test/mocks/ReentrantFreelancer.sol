// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MilestoneEscrow} from "../../src/MilestoneEscrow.sol";

/// @notice A malicious freelancer contract. When it receives ether it immediately
///         tries to claim the same milestone again (a re-entrancy attack).
///         Used only in tests to prove checks-effects-interactions works.
contract ReentrantFreelancer {
    MilestoneEscrow public target;
    uint256 public attackIndex;
    bool public reentryAttempted;
    bool public reentrySucceeded;

    function setTarget(MilestoneEscrow t) external {
        target = t;
    }

    function submit(uint256 i) external {
        target.submitMilestone(i);
    }

    function claim(uint256 i) external {
        attackIndex = i;
        target.claimAfterTimeout(i);
    }

    receive() external payable {
        if (!reentryAttempted) {
            reentryAttempted = true;
            // Status is already Paid, so this must revert with "Not submitted".
            try target.claimAfterTimeout(attackIndex) {
                reentrySucceeded = true;
            } catch {}
        }
    }
}
