# PROJECT CONTEXT FILE — MilestoneEscrow (Blockchain course project)

**How to use this file.** Attach it to the first message of a new chat and write: *"Read the attached project context file fully. Confirm in 5 lines that you understand the project, the constraints and the open decisions. Then wait for my instruction."* Everything the assistant needs is below.

---

## 1. Instructions to the assistant (read first)

You are helping me build and present a small university Blockchain project and keep it consistent across this whole chat.

1. **Treat this file as the source of truth.** If I contradict it, follow my latest message and tell me which line of the file it overrides.
2. **Keep a running state.** Whenever the design or code changes, update section 9 (Current state and changelog) in your head, and when I say **"update the file"**, give me the complete updated version of this file, so I can reuse it in another chat.
3. **Never silently change working code.** When I ask for a change, show (a) the exact lines to change, (b) the full updated function, and (c) what to say if the examiner asks why.
4. **Simplicity is a hard requirement.** I must be able to edit the contract live in front of an examiner. Prefer fewer, clearer lines over clever ones.
5. **Comment every important line** with the smart contract concept it demonstrates.
6. **Test before declaring done.** If you can compile or run tests in your environment, do it; otherwise tell me plainly that the code is untested and give me the exact Remix steps to test it.
7. **My preferences:** no emojis; use numbered lists or bullet points where structure is needed; explain concepts from scratch (define each term when first used) because I must be able to explain everything to my teammate and to the examiner; keep answers focused, not padded.
8. If something is ambiguous and a wrong guess would be expensive, ask me one short question. Otherwise decide, and say what you decided.

---

## 2. Project in one paragraph

**Title:** *Decentralised Milestone-Based Escrow for Freelance Payments using Ethereum Smart Contracts.* **Short name:** MilestoneEscrow.

A client and a freelancer who do not trust each other agree on a project that is split into milestones. The client deploys a smart contract and locks the full payment in it. The freelancer submits each finished milestone, the client approves it, and the contract automatically pays that milestone's share. If the client goes silent, the freelancer can claim after a timeout. If they disagree, a neutral arbiter decides. If the freelancer never delivers, the client can reclaim the money for undelivered milestones. All rules are enforced by code, with no middleman.

---

## 3. Constraints and requirements

1. **Time budget:** buildable in about **3 hours** using AI assistance.
2. **Language:** Solidity. Python is optional ("if necessary"), see open decision D1.
3. **Mandatory smart contract features** (the course requires these):
   - the **entire smart contract concept** covered broadly;
   - a **constructor**;
   - **`view` functions**;
   - the **`require`** keyword.
4. **Changeability:** the implementation must be simple enough that if the examiner asks me to **change something and demonstrate it**, I can edit the code myself in a few minutes. Every concept should live in one clearly identifiable place.
5. **Audience:** a university examiner and a viva. I and my teammate must both be able to explain every line.
6. **Teammate:** one teammate works on this project with me. He needs to understand the topic and what we implement (see section 10).

---

## 4. Why this topic was chosen

Chosen after comparing 20 candidate topics (lending with deposits, sealed-bid auction, crowdfunding, rental deposit, voting, certificate registry, supply chain, chit fund, multisig wallet, digital will, prediction market, lost-and-found, ticketing, time-locked vault, raffle, warranty registry, subscription, bounty board, Dutch auction, and this one). Freelance milestone escrow was selected because it covers the most smart contract concepts for natural reasons: money held in a contract, three roles, several states, deadlines and a trusted third party. It also extends the escrow (Alice/Bob laptop repair) example from the course's Unit 3 slides.

---

## 5. Design specification

### 5.1 Files and structure (one Remix file, three pieces)

1. **`Ownable`** (base contract): stores `owner` and provides the `onlyOwner` modifier. Demonstrates **inheritance**.
2. **`PayMath`** (library): a small `pure` helper that splits a total into equal milestone amounts (the last milestone takes the remainder). Demonstrates **libraries** and **`pure`** functions.
3. **`MilestoneEscrow is Ownable`** (main contract).

### 5.2 Roles

| Role | Who | Powers |
|---|---|---|
| Client | The deployer (`owner`) | Funds the contract, approves milestones, raises disputes, reclaims undelivered milestones |
| Freelancer | Address given to the constructor | Submits milestones, claims after timeout, raises disputes |
| Arbiter | Address given to the constructor | Resolves disputes only |

### 5.3 State

- `immutable`: `freelancer`, `arbiter`, `projectDeadline` (set once in the constructor).
- `constant`: `TIMEOUT = 7 days` (time the client has to respond to a submission).
- `enum Status { Pending, Submitted, Paid, Refunded, Disputed }`
- `struct Milestone { uint amount; Status status; uint submittedAt; }`
- `Milestone[] public milestones;`
- `mapping(address => uint) public reputation;` (count of milestones successfully paid, used as a simple on-chain reputation for the freelancer).

### 5.4 Constructor

`constructor(address payable _freelancer, address _arbiter, uint _milestoneCount, uint _durationDays) payable`

- `require(msg.value > 0, ...)` (client must deposit).
- `require(_milestoneCount > 0, ...)`.
- `require(_freelancer != address(0) && _arbiter != address(0), ...)`.
- `require(_freelancer != msg.sender, ...)`.
- Stores the parties, computes `projectDeadline = block.timestamp + _durationDays * 1 days`.
- Splits `msg.value` across milestones using `PayMath` and pushes the milestones, all `Pending`.

### 5.5 State-changing functions (each has `require` checks)

| Function | Who | Rule (the `require`s) | Effect |
|---|---|---|---|
| `submitMilestone(i)` | freelancer | index valid; status is `Pending`; `block.timestamp <= projectDeadline` | status → `Submitted`; record `submittedAt`; emit `Submitted` |
| `approveMilestone(i)` | client | index valid; status is `Submitted` | status → `Paid` **first**, then transfer amount to freelancer; reputation +1; emit `Paid` |
| `claimAfterTimeout(i)` | freelancer | status is `Submitted`; `block.timestamp >= submittedAt + TIMEOUT` | same as approve (pays freelancer) |
| `raiseDispute(i)` | client or freelancer | status is `Submitted` | status → `Disputed`; emit `Disputed` |
| `resolveDispute(i, bool payFreelancer)` | arbiter | status is `Disputed` | pays freelancer or refunds client; emit `Resolved` |
| `refundPending(i)` | client | status is `Pending`; `block.timestamp > projectDeadline` | status → `Refunded` first, then transfer amount back to client; emit `Refunded` |
| `receive() external payable` | client only (`onlyOwner`) | last milestone still `Pending` | adds the top-up to the last milestone; emit `Deposited` |

### 5.6 `view` / `pure` functions (no gas when called directly)

- `getMilestone(i)` returns amount, status, submittedAt.
- `getBalance()` returns the contract's ether balance.
- `timeLeft(i)` returns seconds until the freelancer may claim (0 if already allowed); reverts with "Not submitted" if the milestone is not submitted.
- `milestoneCount()` returns the number of milestones.
- `PayMath.splitEqual(total, n)` is `pure` (declared `internal`, so it is inlined and cannot be clicked in Remix).

### 5.7 Modifiers

`onlyClient` (via `onlyOwner` from `Ownable`), `onlyFreelancer`, `onlyArbiter`, `validIndex(i)`.

### 5.8 Events

`Submitted(uint index)`, `Paid(uint index, address to, uint amount)`, `Disputed(uint index)`, `Resolved(uint index, bool paidFreelancer)`, `Refunded(uint index, uint amount)`, `Deposited(address from, uint amount)`.

### 5.9 Safety rules to demonstrate

1. **Checks-effects-interactions:** update the status **before** sending ether (prevents re-entrancy).
2. A milestone can never be paid twice (status checks).
3. Only the right role can call each function (modifiers + `msg.sender`).
4. Private helpers `_release(i)` (pay freelancer) and `_refund(i)` (pay client) both call `_send(to, amount)`, the **only** place where ether leaves the contract. `_send` uses `call` with `require(ok)` instead of `transfer`.

### 5.10 Solidity version

Use **Solidity 0.8.x** (Remix default). Note for the viva: the course slides use 0.5 syntax. Differences that matter: in 0.8, `constructor` needs no visibility keyword, arithmetic overflow reverts automatically, and `address payable` must be used for addresses that receive ether.

### 5.11 Known limitation (for the viva)

The contract cannot judge the quality of the work. It relies on the client's approval or the arbiter's decision. This is the same trust problem as the **oracle problem**. The arbiter is a trusted third party, so the design reduces trust but does not eliminate it.

---

## 6. Smart contract concepts covered (checklist for the report)

| Concept | Where in this project |
|---|---|
| State variables | `milestones`, `reputation`, `freelancer`, etc. |
| Constructor (payable) | Section 5.4 |
| Data types: `uint`, `address`, `address payable`, `bool` | Throughout |
| `enum`, `struct`, array, `mapping` | Section 5.3 |
| `payable`, `msg.value`, ether transfer via `call` | Constructor, `_send` |
| `msg.sender` | Modifiers and role checks |
| `require` with messages | Every function |
| `view` and `pure` | Section 5.6 |
| Modifiers | Section 5.7 |
| Events (`emit`) | Section 5.8 |
| `block.timestamp` | Timeout, deadline |
| `immutable` and `constant` | Section 5.3 |
| Inheritance | `Ownable` |
| Library | `PayMath` |
| `receive()` | Top-up |
| Checks-effects-interactions | Section 5.9 |
| Gas | Observed in Remix per call (for the viva) |
| Deployment and testing | Remix (demo) and Foundry test suite with unit, re-entrancy and fuzz tests |

---

## 7. Demo plan (about 5 minutes, Remix)

Remix gives 10 test accounts. Use account 1 as **client**, account 2 as **freelancer**, account 3 as **arbiter**.

1. Deploy as the client with a value of 3 ether, 3 milestones, 30 days.
2. Call `getBalance` and `getMilestone(0)` (views).
3. As the freelancer, `submitMilestone(0)`. Show status = Submitted.
4. As the client, `approveMilestone(0)`. Show the freelancer's balance increase and the `Paid` event in the log.
5. **Failure case:** as the freelancer, try `approveMilestone(1)`. Show the `require` message in the console.
6. **Timeout path:** `submitMilestone(1)`, then show `timeLeft(1)`; explain (or fast-forward with a test build) that the freelancer can claim after 7 days.
7. **Dispute path:** `submitMilestone(2)`, `raiseDispute(2)`, then the arbiter calls `resolveDispute(2, true)`.
8. Show gas used for a few calls.

---

## 8. Likely examiner change requests (the final cheat-sheet must cover these)

The assistant must prepare a one-page "if asked to change X, edit this line" sheet covering at least:

1. Change the number of milestones.
2. Change the timeout from 7 days to something else.
3. Make payments unequal (a custom split).
4. Add a new status or a new rule.
5. Add a platform fee (for example 2%) paid to a fee address.
6. Add a second approver or a second freelancer.
7. Add a maximum deposit or a minimum deposit.
8. Change who can raise a dispute.
9. Add an event or a new `view` function.
10. Make the arbiter the owner, or let the client replace the arbiter.

---

## 9. Current state and changelog (update as we go)

**Status:** v0.1 built and verified. Packaged as a GitHub repo (`milestone-escrow`). Goal widened: exam project **and** resume-worthy team project.

| Item | State |
|---|---|
| Topic chosen | Done |
| Design specification | Done (section 5, with deviations listed below) |
| Contract code | Done: `src/MilestoneEscrow.sol` (~225 lines incl. comments), compiles on 0.8.24 with zero warnings |
| Automated tests | Done: `test/MilestoneEscrow.t.sol` (Foundry: unit, re-entrancy attacker, 2 fuzz tests). Verified behaviour in 13 scenarios on an in-memory chain; Foundry itself not yet run (runs in GitHub CI after first push) |
| Tested in Remix | Not yet (by Ishaan, following `docs/DEMO.md`) |
| Demo script with expected outputs | Done: `docs/DEMO.md` |
| Cheat-sheet for live changes | Done: `docs/CHEATSHEET.md`; all 10 edits compile-checked against the real contract |
| Report | Not started (outline next) |
| Viva questions and answers | Done: `docs/VIVA.md` (28 Q&A) |
| Teammate handout | Done: `docs/TEAM.md` (incl. post-exam roadmap split) |
| Architecture doc | Done: `docs/ARCHITECTURE.md` (state and sequence diagrams, design decisions) |
| CI | Done: `.github/workflows/ci.yml` (build, test, gas report) |
| Python script | No (D1 default) |

**Deviations from the original spec (decided in v0.1)**
1. Ether is sent with `call` + `require(ok)` instead of `transfer` (transfer's 2300-gas limit breaks contract wallets; safety comes from checks-effects-interactions).
2. Money helpers are `_release`, `_refund` and a single `_send`, instead of one `_pay(i, to)`.
3. `submitMilestone` rejects submissions after `projectDeadline` (prevents racing the client's refund).
4. `receive()` accepts only the client and adds the top-up to the last milestone (otherwise ether from others would be stuck forever).
5. `timeLeft` reverts if the milestone is not submitted (avoids an ambiguous 0).

**Changelog**
- Design finalised: extended edition with inheritance, library, `receive()`, timeout, dispute and refund rules.
- v0.1 (2026-11-01): contract, Foundry tests, deploy script, CI, README, architecture, demo, cheat-sheet, viva, team brief.

---

## 10. Teammate briefing (copy for him)

**The idea.** A client wants a website built and a freelancer will build it. Neither trusts the other: if the client pays first the freelancer may vanish, and if the freelancer works first the client may not pay. Normally a platform like Upwork holds the money and charges a fee. We replace that platform with a **smart contract**, a program on the blockchain that holds the money and releases it by fixed rules nobody can change.

**Milestones.** The work is split into stages with a share of the money each, for example 3 ETH split into 3 milestones. The freelancer is paid stage by stage as work is approved.

**Flow.**
1. The client deploys the contract and locks the money.
2. The freelancer submits milestone 1.
3. The client approves, and the contract pays automatically.
4. If the client stays silent for 7 days, the freelancer can claim.
5. If they disagree, a neutral arbiter decides.
6. If the freelancer never delivers by the deadline, the client reclaims the unpaid milestones.

**Why blockchain.** Rules are enforced by code, the money cannot move except by those rules, everything is recorded and visible, and there is no middleman or platform fee.

**Who does what.** One of us writes and tests the contract in Remix. The other writes the report, draws the flow and role diagrams, and prepares the viva answers. We both rehearse the demo twice.

---

## 11. Viva questions and short answers (draft)

1. **Why blockchain for this?** Two distrusting parties need rules that neither can change, without a middleman. The contract holds the money and enforces the rules.
2. **What is a smart contract?** Code deployed on the blockchain (here, Ethereum) that holds ether and data and executes its rules on every node deterministically.
3. **Why is there a constructor, and what does `payable` on it do?** The constructor runs once at deployment to set up the parties; `payable` lets the client send the deposit with the deployment.
4. **What does `require` do?** It checks a condition; if false it reverts the whole transaction, undoing state changes, and returns the message. Gas used is still charged.
5. **What does a `view` function cost?** Nothing when called directly (it only reads state). Calling it from inside a transaction still uses gas.
6. **Why update the status before sending ether?** To prevent a re-entrancy attack, where the receiver calls back before the state is updated and is paid twice.
7. **Why `immutable` and `constant`?** They save gas and make values that never change impossible to alter.
8. **What if the client never responds?** After the timeout the freelancer can claim the payment.
9. **What is the weakness?** The contract cannot judge work quality; it trusts the client or the arbiter, like an oracle.
10. **What is gas?** The fee for computation, equal to gas used times gas price; it also guarantees every execution ends.
11. **Public vs private blockchain for this?** Public Ethereum (or a testnet) is fine; a permissioned chain would suit a company running its own freelancer platform.
12. **What would you add next?** Reputation-based arbiter selection, multiple freelancers, ERC-20 token payments, a web front end.

---

## 12. Open decisions

| # | Question | Default if I do not answer |
|---|---|---|
| D1 | Add a Python `web3.py` script (deploys to Ganache and runs a scripted demo)? | **No. Remix only** |
| D2 | Solidity version | 0.8.x |
| D3 | Do I want a simple web front end (HTML + ethers.js)? | Not for the exam; planned as v0.3 (teammate) after it |
| D4 | Deposit currency | Native ether on a Remix test chain; Sepolia in v0.2 |
| D5 | Repo tooling | **Foundry** (tests in Solidity, CI on GitHub) |

---

## 13. Deliverables the assistant should produce, in this order

1. **`MilestoneEscrow.sol`**: the full commented contract (about 120 to 150 lines), checked to compile.
2. **Remix test walkthrough** with expected result at each step, matching section 7.
3. **Live-change cheat-sheet** covering section 8.
4. **Report outline** (title, problem, objectives, architecture and flow diagram, role diagram, concepts table from section 6, code explanation, testing and screenshots list, limitations, conclusion).
5. **Viva Q&A** (extend section 11).
6. **One-page teammate handout** (polish section 10).
7. Optional: Python demo script (only if D1 changes).

**First action for the new chat:** confirm understanding, then start with deliverable 1.