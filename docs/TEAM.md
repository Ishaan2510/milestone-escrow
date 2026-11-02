# Team brief

## The idea in two minutes

A client wants a website built and a freelancer will build it. Neither trusts the other: if the client pays first the freelancer may vanish; if the freelancer works first the client may not pay. Platforms like Upwork fix this by holding the money and charging a fee.

We replace the platform with a **smart contract**: a program on the Ethereum blockchain that holds the money and releases it by fixed rules nobody can change.

The work is split into **milestones**, for example 3 ETH as three payments of 1 ETH.

1. The client deploys the contract and locks the full payment.
2. The freelancer submits a milestone.
3. The client approves it, and the contract pays automatically.
4. If the client stays silent for 7 days, the freelancer can claim the payment anyway.
5. If they disagree, a neutral **arbiter** decides who gets that milestone's money.
6. If the freelancer never delivers by the deadline, the client takes back the unpaid milestones.

## What each of us owns

### Phase 1: exam (this week)

| Task | Owner |
|---|---|
| Contract, Remix demo, live changes | Ishaan |
| Report, flow and role diagrams | Teammate |
| Viva prep (`docs/VIVA.md`) | Both |
| Two full rehearsals of `docs/DEMO.md` | Both |

Both of us must be able to explain every line. Read the contract top to bottom once; every important line has a `CONCEPT:` comment.

### Phase 2: make it a real project (after the exam)

| Milestone | Owner | Resume line it earns |
|---|---|---|
| v0.2 Sepolia deployment + Etherscan verification | Ishaan | Deployed and verified a smart contract on Ethereum testnet |
| v0.3 Web front end (wallet connect, create escrow, role dashboards) | Teammate | Built a dApp front end with ethers.js/wagmi |
| v0.4 Factory contract + event indexing | Ishaan | Designed a factory pattern and on-chain indexing |
| v0.5 USDC payments, custom splits | Shared | ERC-20 integration |
| v0.6 Slither in CI, invariant tests | Shared | Security tooling |

## How we work in the repo

1. Never push straight to `main`. Create a branch: `git checkout -b feat/frontend`.
2. Open a pull request; CI must be green; the other person reviews.
3. Commit messages: `feat: ...`, `fix: ...`, `test: ...`, `docs: ...`.
4. Any contract change needs a matching test.
