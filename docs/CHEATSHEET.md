# Live-change cheat-sheet

"If the examiner asks to change X, edit this." Line numbers refer to `src/MilestoneEscrow.sol` in v0.1. After every change: **Compile, redeploy, show it working, then show it rejecting a bad case.**

Golden rule for any change: new rule = new `require`; new state = new enum value or variable; new action = new function with a modifier; anything visible = emit an event.

---

## 1. Change the number of milestones
**No code change.** It is the third constructor argument. Redeploy with `5` instead of `3`.
Say: "The count is a deployment parameter, so the same code serves any project size."

## 2. Change the timeout
Line 60:
```solidity
uint256 public constant TIMEOUT = 3 days;   // was 7 days; also: 1 minutes, 12 hours, 2 weeks
```
Say: "`constant` is baked into the bytecode, so changing it needs a new deployment. To make it configurable per project, make it `immutable` and set it in the constructor."

## 3. Unequal payments (custom split)
Replace the constructor's signature and the split loop:
```solidity
constructor(address payable _freelancer, address _arbiter, uint256[] memory _amounts, uint256 _durationDays)
    payable
{
    require(msg.value > 0, "Deposit required");
    require(_amounts.length > 0, "Need at least 1 milestone");
    require(_freelancer != address(0) && _arbiter != address(0), "Zero address");
    require(_freelancer != msg.sender, "Client cannot be freelancer");

    freelancer = _freelancer;
    arbiter = _arbiter;
    projectDeadline = block.timestamp + _durationDays * 1 days;

    uint256 sum;
    for (uint256 i = 0; i < _amounts.length; i++) {
        milestones.push(Milestone(_amounts[i], Status.Pending, 0));
        sum += _amounts[i];
    }
    require(sum == msg.value, "Amounts must add up to deposit");
    emit Deposited(msg.sender, msg.value);
}
```
Remix argument (1 ETH + 2 ETH, Value = 3 ether): `[1000000000000000000,2000000000000000000]`
Say: "The `require` at the end guarantees no ether is left unassigned."

## 4a. Add a new rule: milestones must be done in order
In `submitMilestone`, after the `Not pending` check:
```solidity
require(i == 0 || milestones[i - 1].status == Status.Paid, "Previous milestone not paid");
```
## 4b. Add a new status: client can reject and ask for rework
Add `Rejected` at the **end** of the enum (adding at the end keeps old numbers valid):
```solidity
Disputed, // 4
Rejected  // 5: client wants changes
```
Add the function:
```solidity
function rejectMilestone(uint256 i) external onlyOwner validIndex(i) {
    require(milestones[i].status == Status.Submitted, "Not submitted");
    milestones[i].status = Status.Rejected;
}
```
In `submitMilestone` replace the status check with:
```solidity
require(m.status == Status.Pending || m.status == Status.Rejected, "Not pending");
```

## 5. Platform fee (2 percent)
Quick version (fee pays the arbiter for being available). Replace `_release`:
```solidity
uint256 public constant FEE_PERCENT = 2;

function _release(uint256 i) private {
    Milestone storage m = milestones[i];
    m.status = Status.Paid;
    reputation[freelancer] += 1;
    uint256 fee = (m.amount * FEE_PERCENT) / 100;
    emit Paid(i, freelancer, m.amount - fee);
    _send(payable(arbiter), fee);
    _send(freelancer, m.amount - fee);
}
```
Separate fee wallet: add `address payable public immutable feeWallet;`, add `address payable _feeWallet` to the constructor, set `feeWallet = _feeWallet;`, and send the fee to `feeWallet` instead.
Say: "Because all ether leaves through `_send`, the fee was a three-line change."

## 6a. Second approver (both must approve)
```solidity
address public immutable approver2;                    // set in constructor: approver2 = _approver2;
mapping(uint256 => bool) public clientApproved;
mapping(uint256 => bool) public approver2Approved;

function approveMilestone(uint256 i) external validIndex(i) {   // onlyOwner removed
    require(milestones[i].status == Status.Submitted, "Not submitted");
    if (msg.sender == owner) clientApproved[i] = true;
    else if (msg.sender == approver2) approver2Approved[i] = true;
    else revert("Not an approver");
    if (clientApproved[i] && approver2Approved[i]) _release(i);
}
```
## 6b. Second freelancer
Explain rather than code live: add `address payable worker;` to the `Milestone` struct, take an array of workers in the constructor, and in `_release` pay `m.worker` instead of `freelancer`. `onlyFreelancer` becomes `require(msg.sender == milestones[i].worker)`.

## 7. Minimum or maximum deposit
Constructor, after `Deposit required`:
```solidity
require(msg.value >= 0.1 ether, "Deposit too small");
require(msg.value <= 10 ether, "Deposit too large");
```
Show: deploy with Value = 20 ether, it reverts.

## 8. Change who can raise a dispute
Line 156.
- Only the client: `require(msg.sender == owner, "Only client");`
- Only the freelancer: `require(msg.sender == freelancer, "Only freelancer");`
- Anyone: delete the line.

## 9. New event or new `view` function
New event, emitted when the client approves:
```solidity
event Approved(uint256 index, uint256 time);          // with the other events
emit Approved(i, block.timestamp);                    // first line inside approveMilestone body
```
New view: is the whole project finished?
```solidity
function isComplete() external view returns (bool) {
    for (uint256 i = 0; i < milestones.length; i++) {
        if (milestones[i].status != Status.Paid && milestones[i].status != Status.Refunded) return false;
    }
    return true;
}
```
## 10a. Make the arbiter the owner
**No code change:** deploy with the client's own address as `_arbiter`.
Say: "It works, but it removes neutrality: the client could refund every dispute to himself. That is exactly why the arbiter is a separate role."

## 10b. Let the client replace the arbiter
Line 58: remove `immutable` -> `address public arbiter;` and add:
```solidity
event ArbiterChanged(address oldArbiter, address newArbiter);

function setArbiter(address _new) external onlyOwner {
    require(_new != address(0) && _new != freelancer, "Bad arbiter");
    emit ArbiterChanged(arbiter, _new);
    arbiter = _new;
}
```
Say: "Risk: the client could swap in a friendly arbiter during a dispute. A fair version requires the freelancer's agreement too, or blocks changes while any milestone is Disputed."

---

## Concept locator (where each concept lives)

| Concept | Where |
|---|---|
| Inheritance | `contract MilestoneEscrow is Ownable` |
| Library + `pure` | `PayMath.splitEqual` |
| Constructor + `payable` | `constructor(...) payable` |
| `require` | Every function; constructor has four |
| `view` | `getMilestone`, `getBalance`, `milestoneCount`, `timeLeft` |
| Modifiers | `onlyOwner`, `onlyFreelancer`, `onlyArbiter`, `validIndex` |
| Events | `Submitted`, `Paid`, `Disputed`, `Resolved`, `Refunded`, `Deposited` |
| `enum` / `struct` / array / `mapping` | `Status` / `Milestone` / `milestones` / `reputation` |
| `immutable` / `constant` | `freelancer`, `arbiter`, `projectDeadline` / `TIMEOUT` |
| `block.timestamp` | `submitMilestone`, `claimAfterTimeout`, `refundPending`, `timeLeft` |
| `receive()` | Top-up function |
| Checks-effects-interactions | `_release`, `_refund`, `_send` |
