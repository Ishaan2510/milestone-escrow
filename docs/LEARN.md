# Learn MilestoneEscrow from zero

This guide assumes you know programming (C++, Python) but **nothing about blockchain or these tools**. Every term is explained the first time it appears. Read it top to bottom once; afterwards use the glossary at the end.

---

## Part 0. How complex is this, really?

The repo looks big, but it is **one small program plus layers of tooling around it**. Think of it as rings:

| Ring | Files | What it is | Needed for the exam? |
|---|---|---|---|
| 1. The product | `src/MilestoneEscrow.sol` | The smart contract. About 110 lines of real code, the rest comments. | **Yes. Know every line.** |
| 2. The demo tool | Remix (website, nothing in the repo) | Where you compile, deploy and click buttons in front of the examiner. | **Yes. Practise twice.** |
| 3. Automated tests | `test/`, `foundry.toml`, `lib/forge-std` | Code that checks the contract automatically, 29 checks in under a second. | Good to explain in one sentence. |
| 4. Repo machinery | `.github/workflows/ci.yml`, `script/`, `.env.example`, `foundry.lock` | Runs the tests on GitHub on every push; deploys to real networks later. | No. Resume value only. |

**Remix vs Foundry is not a choice between two versions of the project.** There is only one contract. Remix and Foundry are two different tools that both run that same file:

- **Remix** = a calculator with buttons. You click "deploy", click "approve", and watch. Best for **showing** (the exam).
- **Foundry** = a robot that clicks every button in every order, including attacks, and reports pass/fail. Best for **proving it works** (the resume, the teammate, future changes).

For the exam: **Ring 1 + Ring 2 only**. If asked "how did you test it?", say: "Manually in Remix, and with 29 automated tests in Foundry, including fuzz tests and a re-entrancy attack, which run on GitHub on every push."

---

## Part 1. Blockchain basics (only what this project uses)

1. **Blockchain.** A shared record (a ledger) copied on thousands of computers called **nodes**. New entries are added in batches called **blocks**; each block contains the fingerprint (hash) of the previous one, so changing old data would break every later block. Result: nobody can secretly edit history.

2. **Ethereum.** A blockchain that stores not just balances but also **programs**, and runs them. Its currency is **ether (ETH)**.

3. **Wei.** The smallest unit of ether. **1 ether = 1,000,000,000,000,000,000 wei (10^18).** Contracts always work in wei, like a bank system that stores paise instead of rupees. That is why Remix shows `3000000000000000000` for 3 ETH.

4. **Account / address.** An identity on Ethereum, written as a 40-hex-character **address** like `0x7099...79C8`. Two kinds:
   - **Externally owned account (EOA):** controlled by a person with a private key (a secret number). Client, freelancer and arbiter are EOAs.
   - **Contract account:** controlled by code. Our deployed escrow is one. It has its own address and its own ether balance.

5. **Transaction.** A signed message from an EOA that does something: sends ether, deploys a contract, or calls a contract function that **changes data**. Every transaction is recorded forever.

6. **Gas.** Every step a program runs costs a fixed amount of **gas** (adding numbers is cheap, saving data permanently is expensive). You pay `gas used x gas price` in ether. Two reasons it exists: it pays the nodes for their work, and it guarantees every program stops (an infinite loop simply runs out of gas).

7. **Smart contract.** A program deployed at an address. It has **state** (permanent variables stored on-chain) and **functions**. Once deployed, its code **cannot be changed**. That is the whole point: the rules are fixed and visible to everyone.

8. **Deploy.** Sending a special transaction that uploads the compiled contract. The **constructor** runs once during this transaction.

9. **Revert.** If a check fails mid-transaction, everything that transaction did is undone, as if it never happened. Gas already spent is still paid.

10. **Read vs write.**
    - **Reading** data (calling a `view` function from outside) is **free**: any node answers from its copy, nothing is recorded.
    - **Writing** data needs a transaction and costs gas.

---

## Part 2. The tools, one by one

| Tool | What it is | Analogy | Where you meet it |
|---|---|---|---|
| **Solidity** | The programming language for Ethereum contracts. Syntax looks like C++/JavaScript. | C++ for the blockchain | `.sol` files |
| **solc** | The Solidity **compiler**: turns `.sol` into **bytecode**, the machine code Ethereum runs. Version 0.8.24 here. | `g++` | Runs inside Remix and Foundry |
| **EVM** | Ethereum Virtual Machine: the "CPU" every node uses to run bytecode identically. | JVM for Java | Invisible |
| **Remix** | A website (remix.ethereum.org) with an editor, compiler and a fake blockchain built in. | An online IDE like OnlineGDB, plus a test bank | The exam demo |
| **Remix VM** | A pretend blockchain inside your browser tab, with 10 accounts holding 100 fake ETH each. Resets when you reload. | A sandbox | The "Environment" dropdown in Remix |
| **Foundry** | A command-line toolkit for Solidity, made of four programs: | A build system + test framework | Your Git Bash terminal |
| `forge` | Compiles and **tests** contracts (`forge build`, `forge test`). | `make` + `gtest` | |
| `anvil` | A local blockchain in your terminal (like Remix VM, but outside the browser). | A local server | Optional manual testing |
| `cast` | Sends transactions to and reads data from a blockchain from the terminal. | `curl` for blockchains | Optional manual testing |
| **forge-std** | A library of test helpers (`Test`, `vm.prank`, `assertEq`). Lives in `lib/forge-std`. | The `gtest` library | Imported by the tests |
| **Git / GitHub** | Version control / the website that hosts your repo. | Save history / cloud backup + portfolio | Your repo |
| **Submodule** | A Git pointer to another repo at a fixed version. `lib/forge-std` is one; `.gitmodules` records it. | A bookmark to a specific library version | Why `forge install` was needed |
| **`foundry.lock`** | Records the exact forge-std version installed (v1.17.0). Commit it. | `package-lock.json` | New file in your Source Control panel |
| **CI (GitHub Actions)** | Continuous Integration: on every push, a GitHub server installs Foundry, builds and tests. Green tick = all tests passed. Configured in `.github/workflows/ci.yml`. | An auto-grader that runs on every submission | The Actions tab and the README badge |
| **Linter** | A tool that flags risky-looking patterns (Foundry has one built in). Not errors. | `-Wall` warnings | The 5 warnings you saw |

---

## Part 3. The contract, block by block

Open `src/MilestoneEscrow.sol` next to this guide. The file has **three pieces**.

### 3.1 The header

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
```
- Line 1: the licence (required by the compiler, else a warning).
- `pragma` = "compile this with Solidity 0.8.20 or any newer 0.8.x". 0.8 matters because it **automatically reverts on overflow** (in C++ `uint` overflow wraps around silently; here it fails safely).

### 3.2 Piece 1: `Ownable` (a base contract)

```solidity
contract Ownable {
    address public owner;
    constructor() { owner = msg.sender; }
    modifier onlyOwner() {
        require(msg.sender == owner, "Only client");
        _;
    }
}
```
- `contract` is like `class` in C++.
- `address public owner;` is a **state variable**: stored permanently on the blockchain. `public` makes Solidity auto-generate a free getter function `owner()`, which is why Remix shows an `owner` button.
- **`msg.sender`** = the address that sent the current transaction or call. In a constructor, that is the deployer, so **the deployer becomes the owner (the client)**.
- **`modifier`** = a reusable check you attach to functions. `_;` means "now run the function body here". Equivalent C++ idea: a wrapper that checks a condition, then calls the function.
- **`require(condition, "message")`** = if the condition is false, revert the whole transaction and show the message.

Why a separate contract? To demonstrate **inheritance**: `MilestoneEscrow is Ownable` gets `owner` and `onlyOwner` for free, like `class MilestoneEscrow : public Ownable` in C++.

### 3.3 Piece 2: `PayMath` (a library)

```solidity
library PayMath {
    function splitEqual(uint256 total, uint256 n) internal pure returns (uint256[] memory parts) {
        parts = new uint256[](n);
        uint256 share = total / n;
        for (uint256 i = 0; i < n; i++) parts[i] = share;
        parts[n - 1] += total % n;
    }
}
```
- **`library`** = a collection of helper functions with no storage of its own. Like a namespace of static functions.
- `uint256` = unsigned 256-bit integer, the standard number type.
- **`pure`** = this function reads no blockchain data and changes none; it only computes from its inputs.
- `internal` = only callable from inside our code (the compiler copies it in).
- **`memory`** = temporary storage that disappears after the call (like a local `std::vector`). The opposite is **`storage`** (permanent, on-chain, expensive).
- The logic: 10 wei across 3 milestones = 3, 3, 3, then the remainder 1 goes to the last one = 3, 3, **4**. No wei is lost.

### 3.4 Piece 3: `MilestoneEscrow is Ownable` (the main contract)

**(a) Types**
```solidity
enum Status { Pending, Submitted, Paid, Refunded, Disputed }
struct Milestone { uint256 amount; Status status; uint256 submittedAt; }
```
- **`enum`** = named states, stored as numbers 0 to 4. Remix shows the number, so memorise: **0 Pending, 1 Submitted, 2 Paid, 3 Refunded, 4 Disputed**.
- **`struct`** = groups fields, exactly like a C++ struct.

**(b) State variables**
```solidity
address payable public immutable freelancer;
address public immutable arbiter;
uint256 public immutable projectDeadline;
uint256 public constant TIMEOUT = 7 days;
Milestone[] public milestones;
mapping(address => uint256) public reputation;
```
- **`address payable`** = an address allowed to **receive** ether. The freelancer gets paid, so it must be payable.
- **`immutable`** = set once in the constructor, then frozen forever. Cheap to read.
- **`constant`** = fixed in the source code itself. `7 days` is Solidity shorthand for 604800 seconds.
- `Milestone[] milestones` = a dynamic array, like `std::vector<Milestone>`, stored on-chain.
- **`mapping(address => uint256)`** = a hash map, like `std::unordered_map<address, uint>`, where every key already exists with value 0. `reputation[freelancer]` counts paid milestones.

**(c) Events**
```solidity
event Paid(uint256 index, address to, uint256 amount);
```
- An **event** is a log message written into the transaction receipt with `emit Paid(...)`. Contracts cannot read events, but websites and Remix's console can. It is the contract's way of announcing "this happened". Cheaper than storing data.

**(d) Modifiers** `onlyFreelancer`, `onlyArbiter`, `validIndex(i)`: same idea as `onlyOwner`. `validIndex` stops out-of-range indexes with a clear message.

**(e) The constructor**
```solidity
constructor(address payable _freelancer, address _arbiter, uint256 _milestoneCount, uint256 _durationDays) payable {
    require(msg.value > 0, "Deposit required");
    require(_milestoneCount > 0, "Need at least 1 milestone");
    require(_freelancer != address(0) && _arbiter != address(0), "Zero address");
    require(_freelancer != msg.sender, "Client cannot be freelancer");
    freelancer = _freelancer;
    arbiter = _arbiter;
    projectDeadline = block.timestamp + _durationDays * 1 days;
    uint256[] memory parts = PayMath.splitEqual(msg.value, _milestoneCount);
    for (...) milestones.push(Milestone(parts[i], Status.Pending, 0));
    emit Deposited(msg.sender, msg.value);
}
```
- **`payable`** on the constructor = ether can be sent along with deployment. Without it, deploying with Value = 3 ETH would fail.
- **`msg.value`** = how much wei was sent with this transaction. The 3 ETH you type in Remix's Value box arrives here, and **stays in the contract's balance**.
- Four `require`s: must send money, at least one milestone, no empty addresses (`address(0)` = all zeros, the "null" address), the client cannot hire himself.
- **`block.timestamp`** = the current block's time in seconds since 1970 (Unix time). Deadline = now + days.
- Then split the money and create all milestones as Pending.

Note the **parent constructor** (`Ownable`'s) runs first automatically, so `owner` is already the deployer.

**(f) Freelancer functions**
```solidity
function submitMilestone(uint256 i) external onlyFreelancer validIndex(i) {
    Milestone storage m = milestones[i];
    require(m.status == Status.Pending, "Not pending");
    require(block.timestamp <= projectDeadline, "Project deadline passed");
    m.status = Status.Submitted;
    m.submittedAt = block.timestamp;
    emit Submitted(i);
}
```
- `external` = callable from outside (transactions). 
- **`Milestone storage m = milestones[i];`** = `m` is a **reference** to the real on-chain milestone (like `Milestone& m` in C++). Changing `m` changes the blockchain. Had we written `memory`, it would be a copy and changes would be lost.
- Order of execution: modifiers first (right caller? valid index?), then the requires, then the changes.

`claimAfterTimeout(i)`: if status is Submitted **and** `now >= submittedAt + 7 days`, pay the freelancer. This stops a client from avoiding payment by staying silent.

**(g) Client functions**
- `approveMilestone(i)` (`onlyOwner`): status must be Submitted, then pay.
- `refundPending(i)` (`onlyOwner`): status must be Pending **and** the deadline must have passed, then send that milestone's money back to the client.
- `receive()`: a special function that runs when someone sends plain ether to the contract with no function name. Only the client may do it; the extra money is added to the last milestone so it is never stuck.

**(h) Dispute functions**
- `raiseDispute(i)`: caller must be client or freelancer, status must be Submitted; status becomes Disputed (which also blocks the timeout claim).
- `resolveDispute(i, payFreelancer)` (`onlyArbiter`): status must be Disputed; `true` pays the freelancer, `false` refunds the client.

**(i) View functions (free to call)**
- **`view`** = reads blockchain data but never changes it. Remix shows these as **blue** buttons; no transaction, no gas.
- `getMilestone(i)` returns the three fields; `getBalance()` returns `address(this).balance` (the ether the contract holds); `milestoneCount()`; `timeLeft(i)` returns seconds until the freelancer may claim.

**(j) Money-moving internals (the safety core)**
```solidity
function _release(uint256 i) private {
    Milestone storage m = milestones[i];
    m.status = Status.Paid;           // EFFECT
    reputation[freelancer] += 1;      // EFFECT
    emit Paid(i, freelancer, m.amount);
    _send(freelancer, m.amount);      // INTERACTION (last)
}
function _send(address payable to, uint256 amount) private {
    (bool ok,) = to.call{value: amount}("");
    require(ok, "Ether transfer failed");
}
```
- `private` = only this contract can call it. Nobody can call `_send` directly.
- `to.call{value: amount}("")` = send `amount` wei to `to`. It returns `ok = false` if the receiver rejects it, so we `require(ok)`.
- **Checks-effects-interactions** (the most important security idea here):
  1. **Checks**: the `require`s in the calling function.
  2. **Effects**: update our own data (status = Paid).
  3. **Interactions**: only then send ether to the outside.
- **Why the order matters (re-entrancy):** if the freelancer is itself a contract, receiving ether runs *its* code, which could immediately call `claimAfterTimeout` again **before our first call has finished**. If we sent the ether before setting `Paid`, the status would still be `Submitted` and it would be paid twice. Because we set `Paid` first, the second attempt fails `require(status == Submitted)`. Our test `test_ReentrancyCannotDoublePay` builds exactly this attacker and proves it gets paid once.

---

## Part 4. Trace one milestone through the code

Deploy with 3 ETH, 3 milestones, 30 days, then:

| Step | Who calls | Function | Checks that run | State after | Ether moved |
|---|---|---|---|---|---|
| 1 | Client | constructor | 4 requires | milestones = [1,1,1] ETH, all 0 Pending | Client -> contract 3 ETH |
| 2 | Freelancer | `submitMilestone(0)` | onlyFreelancer, validIndex, Pending, before deadline | m0 = 1 Submitted, submittedAt = now | none |
| 3 | Client | `approveMilestone(0)` | onlyOwner, validIndex, Submitted | m0 = 2 Paid, reputation = 1 | contract -> freelancer 1 ETH |
| 4 | Client | `approveMilestone(0)` again | Submitted fails | unchanged (reverted) | none |

Contract balance after step 3: 2 ETH. Do this trace on paper once; it is the core of every viva answer.

---

## Part 5. How the tests work (enough to explain them)

A Foundry test is a Solidity contract whose functions start with `test`. Example:

```solidity
function test_RevertWhen_FreelancerApproves() public {
    _submit(1);                                  // freelancer submits milestone 1
    vm.prank(freelancer);                        // next call pretends to come from the freelancer
    vm.expectRevert(bytes("Only client"));       // next call must fail with this message
    escrow.approveMilestone(1);                  // the call being tested
}
```
- `setUp()` runs before **every** test: it deploys a fresh escrow with 3 ETH, so tests never affect each other.
- **`vm`** is a "cheat code" object from forge-std that controls the fake blockchain:
  - `vm.prank(addr)`: pretend the next call comes from `addr` (like switching the account dropdown in Remix).
  - `vm.warp(time)`: jump the clock forward (how we test the 7-day timeout without waiting a week).
  - `vm.deal(addr, amount)`: give an address fake ether.
  - `vm.expectRevert(msg)`: the next call must fail with this message, or the test fails.
- `assertEq(a, b)`: fail the test if `a != b`.
- **Fuzz test** = a test with parameters (`testFuzz_SplitConservesDeposit(uint96 deposit, uint8 count)`). Foundry runs it **1000 times with random inputs**, hunting for a case that breaks it. Ours check that no wei is ever lost or created.

The 29 tests in groups: constructor rules (6), happy path (2), wrong caller (4), wrong state (4), timeout (2), disputes (4), refunds (2), top-up (2), re-entrancy attack (1), fuzz (2).

---

## Part 6. Reading your gas report

From your `forge test --gas-report`. Rule of thumb for why numbers differ: **writing to an empty storage slot costs about 20,000 gas, updating a used slot about 5,000, reading a few thousand at most**, and a reverted call stops early so it is cheap.

| Function | Typical gas | Why |
|---|---|---|
| `submitMilestone` | ~69,000 | Writes two empty slots (status 0 -> 1, submittedAt 0 -> time): the two biggest costs. |
| `approveMilestone` | ~50,000 to 67,000 | Updates status, increments reputation, sends ether. The **first** payment is the most expensive because reputation goes from an empty 0 to 1. **Min 23,718** is a call that reverted early. |
| `refundPending` | ~59,000 | Updates status and sends ether. |
| `raiseDispute` | ~32,000 | One status update and an event; no ether moves. |
| `resolveDispute` | up to ~66,000 | Like approve: status update plus a payment. |
| `getBalance` | 228 | Reading the contract's own balance is a single cheap instruction. |
| `getMilestone` | ~9,300 | Reads three storage values. |

**Viva point:** the report shows gas for `view` functions because the tests call them *inside* a test transaction. Called from outside (blue Remix button), they cost **nothing**.

**Deployment cost shows 0** in this report because Foundry did not record the deployment made in `setUp`. Take the real number from Remix: after deploying, expand the transaction in the console and read "transaction cost". Write that in the report.

---

## Part 7. The 5 linter warnings

1. **`block-timestamp` (x4):** validators can nudge a block's time by a few seconds. Dangerous when seconds matter (lotteries). Our windows are 7 and 30 days, so it is harmless.
2. **`arbitrary-send-eth` (x1):** ether is sent to an address held in a variable. In our contract `_send` is `private` and only ever pays the immutable `freelancer` or the `owner`; no outsider chooses the destination.

Saying "the linter flagged these, I checked each and here is why they don't apply" is a strong answer.

---

## Part 8. Glossary

| Term | Meaning |
|---|---|
| `address(0)` | The all-zero address; used as "empty". |
| `address(this)` | This contract's own address. |
| Bytecode | Compiled contract code the EVM runs. |
| `constant` / `immutable` | Fixed in source / fixed at deployment. |
| Constructor | Runs once at deployment. |
| `emit` | Writes an event to the transaction log. |
| `external` / `public` / `private` / `internal` | Who may call: outsiders only / anyone / this contract only / this contract and children. |
| `memory` / `storage` | Temporary copy / permanent on-chain data (reference). |
| `msg.sender` / `msg.value` | Caller's address / wei sent with the call. |
| `payable` | Can receive ether. |
| `pure` / `view` | Touches no state / reads but never writes state. |
| `require` | Check; revert with a message if false. |
| Re-entrancy | A called contract calling back in before the first call finishes. |
| Revert | Undo everything the transaction did. |
| Wei | 10^-18 ether. |

---

## Part 9. Check yourself (answer aloud, then compare with `docs/VIVA.md`)

1. What happens to the 3 ETH when you deploy, and where can you see it?
2. Why is `freelancer` declared `address payable` but `arbiter` is not?
3. What is the difference between `Milestone storage m` and `Milestone memory m`?
4. A freelancer calls `approveMilestone(0)`. Which exact line stops him, and what does Remix show?
5. Why does `_release` set `Paid` before sending ether? Describe the attack it prevents.
6. Why is calling `getBalance` free but `submitMilestone` not?
7. The client never replies. Walk through what the freelancer does and which `require`s must pass.
8. What is the difference between Remix and Foundry, and why did you use both?
