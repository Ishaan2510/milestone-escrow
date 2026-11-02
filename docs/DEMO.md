# Live demo in Remix (about 6 minutes)

## Before the exam (2 minutes of setup)

1. Open <https://remix.ethereum.org>. In the file explorer create `MilestoneEscrow.sol` and paste `src/MilestoneEscrow.sol`.
2. **Solidity compiler** tab: version 0.8.20 or newer, click **Compile**. Expect a green tick and no warnings.
3. **Deploy & run transactions** tab: Environment = **Remix VM**. You get test accounts with 100 ETH each.
4. Copy three addresses into a notepad:
   - Account 1 = **Client**
   - Account 2 = **Freelancer**
   - Account 3 = **Arbiter**
5. Optional, to show the timeout live: change line `TIMEOUT = 7 days` to `TIMEOUT = 1 minutes` and recompile. Say: "In production this is 7 days; I shortened it so we can watch it unlock."

Remix shows `Status` as a number: **0 Pending, 1 Submitted, 2 Paid, 3 Refunded, 4 Disputed**. 1 ether = 1000000000000000000 wei.

## Walkthrough

| # | Account | Action | Expected result | What to say |
|---|---|---|---|---|
| 1 | Client | Contract = `MilestoneEscrow`. **Value = 3, unit Ether**. Deploy args: freelancer, arbiter, `3`, `30`. Click **Deploy**. | Contract appears under "Deployed Contracts". Client balance drops by about 3 ETH. Log shows `Deposited`. | "The constructor runs once, checks four `require` rules and locks 3 ETH split into three milestones." |
| 2 | any | Click `getBalance`, then `getMilestone` with `0`. | `3000000000000000000`; then `1000000000000000000, 0, 0`. | "These are `view` functions. Blue buttons, no transaction, no gas." |
| 3 | Freelancer | `submitMilestone(0)`, then `getMilestone(0)`. | Status `1`, `submittedAt` = a Unix timestamp. Log shows `Submitted`. | "Only the freelancer can submit. The modifier checks `msg.sender`." |
| 4 | Client | Note freelancer balance. `approveMilestone(0)`. | Freelancer balance +1 ETH. `getBalance` = 2 ETH. `reputation(freelancer)` = 1. Log shows `Paid`. | "Status becomes Paid **before** the ether is sent. That is checks-effects-interactions; it stops re-entrancy." |
| 5 | Freelancer | `approveMilestone(1)` | Red error in console: `revert ... Only client`. Nothing changes. | "`require` failed, so the whole transaction reverted. Gas was still charged." |
| 6 | Client | `approveMilestone(0)` again | `revert ... Not submitted`. | "A milestone can never be paid twice." |
| 7 | Freelancer | `submitMilestone(1)`, then `timeLeft(1)`. | `604800` (7 days in seconds) or about `60` if shortened. | "If the client goes silent, the freelancer is not stuck." |
| 7b | Freelancer | Only if TIMEOUT was shortened: wait a minute, call `claimAfterTimeout(1)`. | Freelancer +1 ETH, status `2`. | "No approval was needed. Silence cannot be used to avoid paying." |
| 8 | Freelancer | `submitMilestone(2)`, then `raiseDispute(2)`. | Status `4`, log shows `Disputed`. | "Either party can freeze the milestone for the arbiter." |
| 9 | Client | `resolveDispute(2, true)` | `revert ... Only arbiter`. | "Only the neutral party can decide." |
| 10 | Arbiter | `resolveDispute(2, true)` | Freelancer +1 ETH, status `2`, `getBalance` = 0, events `Resolved` and `Paid`. | "The arbiter chose to pay. `false` would refund the client." |
| 11 | any | Expand any transaction in the console. | Shows `gas` and `transaction cost`. | "Gas is the fee for computation. View calls cost nothing; writes cost gas." |

## Optional extras

- **Refund path:** deploy a second contract with `durationDays = 0` and 1 ether, 1 milestone. Wait a few seconds, then as the client call `refundPending(0)`. Client gets the ether back.
- **Top-up (`receive`):** as the client, put 1 ether in **Value**, scroll to "Low level interactions" at the bottom of the deployed contract and click **Transact** with empty calldata. `getMilestone(2)` now shows the last milestone increased by 1 ether. The same from the arbiter account reverts with `Only client`.
- **Deployment failure:** deploy with Value = 0. Expect `revert ... Deposit required`.

## If something goes wrong

| Symptom | Cause | Fix |
|---|---|---|
| `Only freelancer` when you expected success | Wrong account selected | Switch the ACCOUNT dropdown |
| `Deposit required` on deploy | Value field is 0 or unit is Wei | Set 3 and unit Ether |
| `Zero address` | An address argument is empty | Paste the full 0x address |
| `Project deadline passed` | Deployed with `durationDays = 0` | Redeploy with 30 |
