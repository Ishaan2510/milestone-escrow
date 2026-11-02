# Exam prep: presentation and live changes

Three parts:
1. **How to present** (a 10-minute script, split between two people).
2. **How to handle any change request** (one recipe that works for anything).
3. **14 concept drills**, each a likely examiner request, with exact code. Every drill was compiled and run against the real contract, and all of them work.

Read `docs/LEARN.md` Parts 0, 1 and 3 first. This file assumes you know what the code does.

---

## Part A. Use Remix to present

Yes, present in Remix. It makes your work easier to explain, for four reasons:
1. **It's visual.** The examiner watches you click "submitMilestone" as the freelancer and sees the status change. Nobody has to read terminal output.
2. **It's what the course uses.** The examiner knows the interface, so you spend no time explaining the tool.
3. **Live edits are fast.** Edit, then Ctrl+S (it auto-compiles), then Deploy. A change takes under a minute to show.
4. **Account switching makes the roles concrete.** The ACCOUNT dropdown *is* "now I am the freelancer".

Foundry gets **30 seconds** near the end (Part B, step 5) as proof of quality. You don't need to demo it.

---

## Part B. The presentation script (about 10 minutes)

### Before you walk in (15 minutes of setup)

1. Open <https://remix.ethereum.org>. Create two files:
   - `MilestoneEscrow.sol`: the original from `src/`.
   - `MilestoneEscrowDemo.sol`: a copy with `TIMEOUT = 1 minutes`, so the timeout path can be shown live.
2. Compile both. Check for a green tick.
3. Set Environment = Remix VM. Write down the three account addresses:
   - Account 1: client
   - Account 2: freelancer
   - Account 3: arbiter
4. Open a second browser tab with your GitHub repo (green CI badge, README diagram).
5. Optional: have the VS Code terminal ready in the repo folder for `forge test`.
6. **Backup plan:** if the internet fails, Remix won't load. Keep the report with screenshots of every demo step, and a local copy of the repo.

### The script

| # | Time | Who | What to do | What to say |
|---|---|---|---|---|
| 1 | 1 min | Teammate | No screen needed | "A client and a freelancer don't trust each other. Whoever goes first takes a risk. Platforms like Upwork solve this by holding the money and charging 10 to 20 percent. We replaced the platform with a smart contract: it holds the money and pays out by rules nobody can change." |
| 2 | 1 min | Teammate | README state diagram on GitHub, or draw it | "Three roles: client, freelancer, arbiter. The work is split into milestones. Each milestone moves Pending, Submitted, Paid. A silent client loses after 7 days. Disagreements go to the arbiter. Undelivered work is refunded after the deadline." |
| 3 | 3 min | You | Scroll through the contract in Remix | Walk top to bottom, naming one concept per block. "`Ownable` shows inheritance. `PayMath` is a library with a pure function. Here is the enum and struct, the mapping for reputation, immutable and constant. The constructor is payable and has four requires. Modifiers handle roles. View functions are free. And this is the core safety rule: in `_release` we set the status to Paid **before** sending ether." |
| 4 | 4 min | You | Remix demo: `docs/DEMO.md` steps 1 to 6, then 8 to 10 | Narrate each click. Always show at least **one failure**, such as the freelancer trying to approve. The red `Only client` message proves `require` works. |
| 5 | 30 s | Teammate | GitHub CI badge, or run `forge test` in the terminal | "We also wrote 29 automated tests in Foundry, including a re-entrancy attack and fuzz tests with 1000 random inputs each. They run on GitHub on every push." |
| 6 | 30 s | Teammate | No screen needed | "Limitation: the contract can't judge work quality, so it trusts the client or the arbiter. That's the oracle problem. Next steps: a factory contract, stablecoin payments and a web front end." |

**Rules while presenting:**
- Say the concept name out loud every time you use one ("this is a modifier", "this is a view function, so no gas"). Examiners mark concepts they hear.
- If something fails unexpectedly, read the red error message aloud. It usually names the cause, for example "Only freelancer" means the wrong account is selected. Fixing it calmly scores better than a perfect run.
- Both of you must be able to do step 3 alone. The examiner may ask the teammate to explain a line.

---

## Part C. The recipe for any change request

Whatever the examiner asks, answer these four questions. Most changes need only one or two of them.

| Question | If yes, use | Example |
|---|---|---|
| 1. Do we need to **remember something new**? | A state variable, struct field or mapping | "track total earned" |
| 2. Is there a **new rule**? | A `require(condition, "message")` | "max 10 milestones" |
| 3. Is it about **who** may do it? | A modifier, or a `require(msg.sender == ...)` | "only parties can dispute" |
| 4. Should the outside world **know it happened**? | An `event` plus `emit` | "log approvals" |

Then always follow the same **5-step loop** in Remix:
1. **Edit** the code.
2. **Ctrl+S** to compile. Fix any red error the compiler underlines.
3. **Redeploy**. Explain why: "A deployed contract's code can never change. That's blockchain immutability, so a new version means a new deployment at a new address."
4. **Show it working** (the success case).
5. **Show it rejecting** (the failure case). This is the step that proves your `require` or modifier.

Step 3 is free marks. Say the immutability sentence every single time.

**Compiler errors you will likely hit while editing live:**

| Error says | Meaning | Fix |
|---|---|---|
| `Expected ';'` | Missing semicolon | Add it on the line above the underline |
| `Undeclared identifier` | Misspelt a name, or used something not declared yet | Check spelling; declare the variable |
| `Wrong argument count for struct constructor` | You added a struct field but not to `Milestone(...)` | Add the new value in the `milestones.push(...)` line |
| `Type uint256 is not implicitly convertible to uint64` | Assigning a big type to a small one | Cast it: `uint64(value)` |
| `Function declared as view, but this expression modifies the state` | Writing data inside a `view` function | Remove `view`, or don't write |

---

## Part D. 14 concept drills (practise each in Remix)

Each drill lists the request, the concept, **where** to edit (find that text in the file), the code, how to show it, and what to say. They are sorted from easiest to hardest. Do D1 to D7 until you can type them without looking; for D8 to D14, understand them and practise them at least once.

### D1. "Add a view function" (concept: `view`, enum as a parameter, loops)
**Where:** above the `// ---- views` comment.
```solidity
function countByStatus(Status s) external view returns (uint256 count) {
    for (uint256 i = 0; i < milestones.length; i++) {
        if (milestones[i].status == s) count++;
    }
}
```
**Show:** after paying milestone 0, `countByStatus(2)` returns 1 and `countByStatus(0)` returns 2.
**Say:** "View, so it costs no gas when called from outside. The enum is passed as a number: 2 means Paid."

### D2. "Add a pure function" (concept: `pure`, ether units, integer division)
**Where:** same place.
```solidity
function weiToEther(uint256 amountWei) external pure returns (uint256) {
    return amountWei / 1 ether;
}
```
**Show:** `weiToEther(3700000000000000000)` returns `3`.
**Say:** "Pure means it doesn't even read state. Solidity has no decimals, so 3.7 becomes 3. That's why contracts store amounts in wei."

### D3. "Add a validation rule" (concept: `require`, unbounded loops)
**Where:** constructor, after `Need at least 1 milestone`.
```solidity
require(_milestoneCount <= 10, "Too many milestones");
```
**Show:** deploying with 11 fails with `Too many milestones`.
**Say:** "The constructor loops once per milestone. Each iteration costs gas, and a block has a gas limit, so loops must be bounded. Otherwise deployment could run out of gas."

### D4. "Make a new modifier" (concept: modifiers, access control)
**Where:** add it next to the other modifiers. In `raiseDispute`, add `onlyParties` to the signature and **delete** the old `require(msg.sender == owner || ...)` line.
```solidity
modifier onlyParties() {
    require(msg.sender == owner || msg.sender == freelancer, "Not a party");
    _;
}

function raiseDispute(uint256 i) external onlyParties validIndex(i) {
```
**Show:** the arbiter calling `raiseDispute` gets `Not a party`.
**Say:** "Same behaviour, now reusable on any function. `_;` is where the function body runs after the check."

### D5. "Add an event" (concept: events, `indexed`)
**Where:** with the other events; the `emit` goes in `approveMilestone` after its `require`.
```solidity
event Approved(uint256 indexed index, address by, uint256 time);

emit Approved(i, msg.sender, block.timestamp);
```
**Show:** in the Remix console, expand the approve transaction and find `Approved` under "logs".
**Say:** "Events are cheap logs for front ends. `indexed` makes a field searchable, so an app can ask for all approvals of milestone 2."

### D6. "Add a payable function" (concept: `payable`, `msg.value`)
**Where:** above the views.
```solidity
function addToMilestone(uint256 i) external payable onlyOwner validIndex(i) {
    require(msg.value > 0, "Send some ether");
    require(milestones[i].status == Status.Pending, "Not pending");
    milestones[i].amount += msg.value;
    emit Deposited(msg.sender, msg.value);
}
```
**Show:** set Value = 0.5 Ether and call `addToMilestone(1)`. `getMilestone(1)` shows 1.5 ETH and `getBalance` shows 3.5 ETH.
**Say:** "Without `payable`, any call sending ether is rejected automatically. `msg.value` is the amount sent."

### D7. "Add a mapping" (concept: mappings, effects before interactions)
**Where:** declare it next to `reputation`; increment it inside `_release`, under the reputation line, **before** `_send`.
```solidity
mapping(address => uint256) public totalEarned;

totalEarned[freelancer] += m.amount;
```
**Show:** after two approvals, `totalEarned(freelancer)` = 2 ETH.
**Say:** "A mapping is a hash map where every key starts at 0. I put the update before `_send` to keep checks-effects-interactions."

### D8. "Add a field to the struct" (concept: structs, strings, `calldata`)
**Where:** add the field at the end of the struct. Fix the `push` line, which needs a 4th value. Add the setter above the views.
```solidity
string description; // inside struct Milestone

milestones.push(Milestone(parts[i], Status.Pending, 0, ""));

function setDescription(uint256 i, string calldata d) external onlyOwner validIndex(i) {
    require(milestones[i].status == Status.Pending, "Not pending");
    milestones[i].description = d;
}
```
**Show:** `setDescription(0, "Homepage design")`, then click the `milestones` getter with `0`.
**Say:** "`calldata` is read-only input data, cheaper than memory. Storing text on-chain is expensive, so real apps store a hash or an IPFS link instead."

### D9. "Add a new state" (concept: enums, reusing the safety pattern)
**Where:** add `Cancelled` at the **end** of the enum (put a comma after `Disputed`). Add the function above the views.
```solidity
Cancelled // 5: client cancelled before work started

function cancelMilestone(uint256 i) external onlyOwner validIndex(i) {
    Milestone storage m = milestones[i];
    require(m.status == Status.Pending, "Not pending");
    m.status = Status.Cancelled;      // effect first
    _send(payable(owner), m.amount);  // interaction last
}
```
**Show:** `cancelMilestone(2)` makes the status 5 and the balance drops by 1 ETH.
**Say:** "New states go at the end so the existing numbers don't shift. Status changes before ether moves, the same re-entrancy protection as before." Then raise the trade-off yourself: "It's unfair if the freelancer has already started, so a fair version would need his agreement."

### D10. "Use inheritance to add a pause switch" (concept: inheritance chain, circuit breaker)
**Where:** a new contract between `Ownable` and `PayMath`. Change the escrow line to `is Pausable`. Add `whenNotPaused` to `submitMilestone`.
```solidity
contract Pausable is Ownable {
    bool public paused;

    modifier whenNotPaused() {
        require(!paused, "Paused");
        _;
    }

    function setPaused(bool p) external onlyOwner {
        paused = p;
    }
}

contract MilestoneEscrow is Pausable {

function submitMilestone(uint256 i) external onlyFreelancer whenNotPaused validIndex(i) {
```
**Show:** `setPaused(true)`, then submitting fails with `Paused`; `setPaused(false)`, then it works.
**Say:** "The chain is MilestoneEscrow inherits Pausable, which inherits Ownable, so `onlyOwner` still works. This is the circuit-breaker pattern, used to stop a contract in an emergency."

### D11. "Make it pull payments instead of push" (concept: the withdraw pattern, security)
**Where:** declare the mapping next to `reputation`. In `_release`, replace the `_send(freelancer, m.amount)` line. Add `withdraw` above the views.
```solidity
mapping(address => uint256) public withdrawable;

withdrawable[freelancer] += m.amount; // replaces _send(...) in _release

function withdraw() external {
    uint256 amount = withdrawable[msg.sender];
    require(amount > 0, "Nothing to withdraw");
    withdrawable[msg.sender] = 0;          // effect first
    _send(payable(msg.sender), amount);    // interaction last
}
```
**Show:** after approving, `getBalance` is still 3 ETH and `withdrawable(freelancer)` = 1 ETH. The freelancer calls `withdraw`, and a second `withdraw` fails.
**Say:** "Push means the contract sends. Pull means the user collects. Pull is safer: if a receiver's code fails or misbehaves, it only affects that receiver's own withdrawal, not our approval function."

### D12. "Add a fallback function" (concept: `fallback` vs `receive`)
**Where:** above the views.
```solidity
fallback() external payable {
    revert("Unknown function");
}
```
**Show:** at the bottom of the deployed contract, under "Low level interactions", enter CALLDATA `0x12345678` and click Transact. It reverts with `Unknown function`.
**Say:** "`receive` runs when ether arrives with **empty** data. `fallback` runs when the data matches **no function**. Ours rejects mistakes loudly instead of silently swallowing them."

### D13. "Optimise gas" (concept: storage slots, packing)
**Where:** in the struct, change the `submittedAt` type. In `submitMilestone`, add the cast.
```solidity
uint64 submittedAt; // was uint256; now shares a storage slot with status

m.submittedAt = uint64(block.timestamp);
```
**Show:** compare the `submitMilestone` transaction cost before and after. In our test it dropped from **69,368 to 47,279 gas, saving 22,089 (about 32%)**.
**Say:** "Storage is organised in 32-byte slots, and writing a fresh slot costs about 20,000 gas. `status` is 1 byte and a `uint64` is 8 bytes, so both now fit in one slot. One slot write instead of two. A `uint64` timestamp lasts billions of years, so nothing is lost."

### D14. "Let the owner transfer ownership" (concept: access control, inheritance)
**Where:** inside `Ownable`, after the modifier.
```solidity
event OwnershipTransferred(address from, address to);

function transferOwnership(address newOwner) external onlyOwner {
    require(newOwner != address(0), "Zero address");
    emit OwnershipTransferred(owner, newOwner);
    owner = newOwner;
}
```
**Show:** transfer to account 4. Account 1 calling `approveMilestone` now fails with `Only client`.
**Say:** "Added once in the base contract, it works in the escrow through inheritance. To be safe I'd also block transferring ownership to the freelancer."

---

## Part E. Requests to answer, not code

| If asked | Answer |
|---|---|
| "Change the deployed contract." | "It can't be changed. That's immutability. I redeploy a new version. Real projects use a **proxy pattern**: a fixed address that forwards calls to a replaceable logic contract." |
| "Make the data private." | "`private` only stops other contracts from reading it. Every node stores all data, so anyone can read it from storage. Real secrecy needs encryption or a hash (a commitment)." |
| "Use `tx.origin` instead of `msg.sender`." | "`tx.origin` is the original human who started the transaction. If a malicious contract tricks the client into calling it, `tx.origin` is still the client, so checks would pass. `msg.sender` is the immediate caller, which is safe." |
| "Add randomness, e.g. pick a random arbiter." | "A blockchain has no true randomness. Every node must compute the same result, and block values can be influenced by validators. Use an oracle such as Chainlink VRF." |
| "Use `block.number` for the timeout." | "Possible: 7 days is about 50,400 blocks at 12 seconds per block. Time-based is easier to read; block-based can't be nudged by validators. In Remix VM every transaction mines a block, so a block-based timeout is easy to demo." |
| "Add `selfdestruct`." | "It's deprecated. Since the 2024 Cancun upgrade it only deletes a contract within the same transaction that created it. To 'close' a contract, refund everything and block further calls instead." |
| "What if the numbers overflow?" | "Solidity 0.8 checks automatically and reverts. The `unchecked { }` block turns the checks off to save gas when overflow is impossible." |
| "Why is `getBalance` free but the gas report shows 228?" | "Called from outside, a view costs nothing. The report measures it called *inside* a transaction, as the tests do." |

---

## Part F. Practice plan

**Session 1 (60 minutes): understand**
1. Read `LEARN.md` Parts 0, 1 and 3 with the contract open beside it.
2. Do the full `DEMO.md` walkthrough once, slowly.
3. Explain the contract aloud to your teammate, top to bottom, without notes.

**Session 2 (90 minutes): drills**
1. In Remix, do D1 to D7. For each one:
   - Read the drill.
   - **Close this file.**
   - Type the change from memory.
   - Compile, redeploy, show success, show failure.
2. Repeat any drill that took more than 3 minutes.
3. Do D8 to D14 once each, reading along.

**Session 3 (45 minutes): mock exam**
1. Your teammate plays the examiner. He picks 3 random drills from Part D and 3 questions from Part E or `VIVA.md`.
2. Give the full 10-minute presentation (Part B) with a timer.
3. Swap roles, so he also presents the code walkthrough once.

**The night before:**
1. Do one fresh Remix setup from scratch.
2. Re-read Part C (the recipe) and Part E.

**Target:** any D1 to D7 change done, deployed and demonstrated in **under 3 minutes**.
