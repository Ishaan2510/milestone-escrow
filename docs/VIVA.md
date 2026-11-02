# Viva questions and answers

Each answer is short enough to say aloud. Terms are defined the first time they appear.

## A. Why this project

1. **What problem does it solve?**
   Two parties who do not trust each other (client and freelancer) must exchange money for work. Whoever goes first takes a risk: this is **counterparty risk**, the risk that the other side will not keep its promise. Platforms like Upwork solve it by holding the money and charging a fee. Our smart contract holds the money instead and releases it by fixed rules.

2. **Why use a blockchain at all?**
   Several parties share one record, they distrust each other, and we do not want a middleman. A blockchain gives a shared record that nobody can secretly edit, and code that runs the same way on every node. If a trusted operator already existed and worked well, a blockchain would add cost without value.

3. **Why milestones instead of one payment?**
   Smaller steps mean smaller risk. The freelancer never works long without pay, and the client never pays far ahead of delivered work.

## B. Smart contract basics

4. **What is a smart contract?**
   A program stored on the blockchain at its own address. It holds data and ether, and every node runs its code identically (deterministically). Once deployed, its code cannot be changed.

5. **What is the constructor, and why `payable`?**
   A special function that runs exactly once, at deployment. Ours checks the inputs, stores the three parties, sets the deadline and splits the deposit. `payable` allows ether to be sent with the deployment; without it, sending ether would fail.

6. **What does `require` do?**
   It checks a condition. If the condition is false, the whole transaction is **reverted**: every change it made is undone and the error message is returned. Gas used up to that point is still paid.

7. **Difference between `view` and `pure`?**
   `view` reads blockchain state but never changes it (`getBalance`). `pure` neither reads nor changes state; it only computes from its inputs (`PayMath.splitEqual`). Both are free when called directly from outside, because no transaction is needed.

8. **What is a modifier?**
   Reusable code that runs before a function body. The `_;` marks where the function body goes. `onlyFreelancer` checks `msg.sender` once and is reused on every freelancer function.

9. **What are `msg.sender` and `msg.value`?**
   `msg.sender` is the address that called the function. `msg.value` is the amount of ether (in wei) sent with the call. 1 ether = 10^18 wei.

10. **What are events?**
    Logs written by the contract during a transaction. They are cheap, cannot be read by contracts, but front ends and block explorers read them to show what happened.

11. **`immutable` vs `constant`?**
    `constant` is fixed in the source code (`TIMEOUT`). `immutable` is set once in the constructor (`freelancer`). Both are stored inside the bytecode, so they are cheaper to read than normal storage and can never change.

12. **What is a `mapping`?**
    A key-value table. `reputation[address]` returns how many milestones that address has been paid for. Every key exists and starts at 0.

13. **What is inheritance here?**
    `MilestoneEscrow is Ownable`: the escrow gets `owner` and `onlyOwner` from the base contract without rewriting them.

14. **What is a library?**
    Reusable code with no storage of its own. `PayMath` holds the split calculation so the main contract stays readable.

15. **What does `receive()` do?**
    It runs when someone sends plain ether to the contract with no function call. Ours accepts only the client and adds the top-up to the last milestone, so no ether can get stuck.

## C. Security

16. **What is re-entrancy, and how do you prevent it?**
    When a contract sends ether to another contract, the receiver's code runs and can call back into the sender before the first call finishes. If the sender has not yet marked the milestone as paid, the attacker can be paid twice. We prevent it with **checks-effects-interactions**: check conditions, update state (status = Paid), and only then send ether. Our test `test_ReentrancyCannotDoublePay` uses a malicious contract to prove the second claim fails.

17. **Why `call` instead of `transfer`?**
    `transfer` forwards only 2300 gas, which can make payments to smart-contract wallets fail. `call` forwards enough gas, and we check its return value with `require(ok)`. Safety comes from checks-effects-interactions, not from the gas limit.

18. **Can a milestone be paid twice?**
    No. Every paying function requires a specific status (`Submitted` or `Disputed`), and that status is changed to `Paid` before the ether leaves.

19. **What if the client never responds?**
    After 7 days the freelancer calls `claimAfterTimeout` and is paid without approval.

20. **What if the freelancer disappears?**
    After the project deadline the client calls `refundPending` for each undelivered milestone. Submissions after the deadline are blocked so the freelancer cannot race the refund.

21. **Can ether get stuck in the contract?**
    No. Every wei belongs to a milestone, and every milestone ends Paid or Refunded. Our fuzz test checks this for random deposits, counts and outcomes.

## D. Gas and Ethereum

22. **What is gas?**
    A unit measuring computation. Fee = gas used x gas price. It pays validators and guarantees every execution ends, because a transaction stops when its gas runs out.

23. **Why are some Remix buttons blue and some orange?**
    Blue = `view`/`pure` calls: read-only, free, no transaction. Orange = state-changing transactions: they cost gas. Red = `payable` functions.

24. **What changed between Solidity 0.5 (slides) and 0.8 (ours)?**
    Arithmetic overflow now reverts automatically, the constructor needs no visibility keyword, and only `address payable` can receive ether.

## E. Limitations and extensions

25. **What is the weakness of your design?**
    The contract cannot judge work quality; it trusts the client's approval or the arbiter's decision. This is the **oracle problem**: on-chain code cannot see off-chain facts. We reduce trust to one neutral arbiter; we do not remove it.

26. **Public or private blockchain?**
    Public Ethereum (or a testnet like Sepolia) suits independent clients and freelancers. A permissioned chain would suit one company running its own internal freelancer platform.

27. **What would you add next?**
    A factory contract to create escrows in one click, stablecoin (ERC-20) payments so prices do not swing with ETH, a web front end, and arbiter selection based on reputation.

28. **How did you test it?**
    Live in Remix for the demo, plus an automated Foundry test suite: unit tests for every rule, a re-entrancy attack test, and fuzz tests (random inputs) that check no ether is lost. CI runs them on every push to GitHub.
