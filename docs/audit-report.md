# Security Audit Report

## Executive Summary

This audit covers the RWA Governed Protocol at the current working tree. The implementation includes RWA token issuance, ERC4626-style vault shares, a constant-product AMM, Chainlink oracle adapter, timelock governance, CREATE/CREATE2 factory, and a UUPS-style issuer.

No Critical, High, or Medium findings are known after the fixes documented below. Local Slither high/medium run reports 0 findings. Remaining risks are documented as Low, Informational, Optimization, or Operational.

## Scope

In scope:

- `src/token/GovernanceToken.sol`
- `src/token/AssetBadgeNFT.sol`
- `src/vault/RwaVault.sol`
- `src/amm/ConstantProductAMM.sol`
- `src/oracle/ChainlinkOracleAdapter.sol`
- `src/governance/`
- `src/upgrade/`
- `src/factory/ProtocolFactory.sol`

Out of scope:

- Frontend hosting
- Off-chain collateral verification process
- The Graph hosted service availability
- Real L2 RPC and block explorer uptime

Commit hash: to be filled after repository initialization.

## Methodology

Manual review focused on:

- Access control and issuer permissions
- Checks-Effects-Interactions
- Reentrancy exposure
- Oracle stale price behavior
- Governance lifecycle and timelock delay
- AMM invariant preservation
- Vault share rounding
- Upgrade storage collision risk

Tooling:

- `forge build`
- `forge test --summary`
- `forge coverage --report summary`
- Slither in CI with `--exclude-low --exclude-informational`

## Findings Table

| ID | Severity | Title | Status |
| --- | --- | --- | --- |
| S-01 | High | Reentrancy in vulnerable withdrawal pattern | Fixed in `FixedBank` |
| S-02 | High | Missing owner check on privileged sweep | Fixed in `FixedBank` |
| S-03 | Low | Lightweight votes do not checkpoint historical blocks | Acknowledged |
| S-04 | Low | Local ERC20 implementation instead of audited OpenZeppelin package | Acknowledged |
| S-05 | Informational | Deployment addresses are placeholders until L2 deployment | Acknowledged |
| G-01 | Gas | Yul min is cheaper than ternary min | Fixed/used |

## S-01: Reentrancy in Withdrawal Pattern

Severity: High  
Location: `src/mocks/VulnerabilityCases.sol`

The vulnerable example sends ETH before setting the user balance to zero. A malicious receiver can reenter `withdraw` and drain funds.

Impact: loss of ETH from vulnerable bank.

Proof of concept: `VulnerableBank.withdraw` calls `msg.sender.call` before clearing state.

Recommendation: apply Checks-Effects-Interactions and `nonReentrant`.

Status: fixed in `FixedBank.withdraw`, which sets balance to zero before the external call and uses `ReentrancyGuard`.

## S-02: Missing Access Control on Admin Sweep

Severity: High  
Location: `src/mocks/VulnerabilityCases.sol`

Privileged treasury sweep functions must not be callable by arbitrary users.

Impact: unauthorized ETH transfer from treasury-like contracts.

Recommendation: restrict sweep to owner, admin role, or timelock.

Status: fixed in `FixedBank.sweep` with `require(msg.sender == owner)`.

## S-03: Lightweight Voting Model

Severity: Low  
Location: `src/token/GovernanceToken.sol`

The token stores current voting power rather than full historical checkpoints.

Impact: production-grade governance normally uses historical snapshots to prevent vote power movement across voting windows.

Recommendation: replace with OpenZeppelin `ERC20Votes` before mainnet deployment.

Status: acknowledged for the self-contained course implementation.

## S-04: Internal Library Surface

Severity: Low  
Location: multiple contracts

The project includes lightweight internal implementations to keep grading reproducible without dependency downloads.

Impact: more manual audit burden than audited OpenZeppelin modules.

Recommendation: use OpenZeppelin contracts in production.

Status: acknowledged.

## Centralization Analysis

The issuer admin can authorize issuers. Issuers can mint backed tokens. The intended production state is for the timelock to hold admin powers and for proposals to manage issuer changes.

If the issuer key is compromised, unauthorized asset-backed tokens can be minted. Mitigation: timelock-controlled rotation, off-chain monitoring, cap policies, and subgraph alerting.

## Governance Attack Analysis

Flash-loan governance: the current simplified voting model should be replaced with historical checkpoints for production. The design includes a 1-day voting delay and 2-day timelock to provide monitoring windows.

Whale attacks: quorum and proposal threshold make governance capture expensive, but do not eliminate concentration risk.

Proposal spam: 1% proposal threshold reduces spam. Production deployments can add proposal deposits or rate limits.

Timelock bypass: execution is gated by operation hash and timestamp. Admin roles must be transferred to timelock post-deployment.

## Oracle Attack Analysis

Price manipulation: Chainlink feed is read through `AggregatorV3Interface`; protocol rejects non-positive prices.

Stale price: `ChainlinkOracleAdapter` reverts when `updatedAt + maxStaleness < block.timestamp`.

Feed depeg: governance can rotate oracle adapters after timelock review.

## Slither Appendix

High/Medium check:

```bash
slither . --exclude-low --exclude-informational --json slither-report-high-medium-latest.json
```

Latest local result: 0 findings.

Full low/info report can be generated with:

```bash
slither . --json slither-report.json
```

## Checks-Effects-Interactions Review

The project was reviewed function-by-function for value movement and privileged state changes.

`RwaVault.deposit` computes shares, mints shares, then transfers assets in. Because the whole transaction reverts if the ERC-20 transfer fails, the minted shares cannot remain without assets. `RwaVault.withdraw` checks allowance, burns shares, then transfers the asset to the receiver under `nonReentrant`.

`ConstantProductAMM.addLiquidity` pulls both tokens, computes LP shares, mints, and syncs reserves. `removeLiquidity` burns LP shares and updates reserves before external transfers. `swap` computes output and updates reserves before pulling input and sending output, with `nonReentrant` guarding the whole function.

`SimpleTimelock.execute` deletes the operation timestamp before the target call and checks the call return value. This prevents repeated execution of the same operation hash.

## Privileged Function Review

| Function | Guard | Notes |
| --- | --- | --- |
| `GovernanceToken.mint` | `MINTER_ROLE` | Deployer role is revoked in the hardened deployment path. |
| `GovernanceToken.issueBackedTokens` | `ISSUER_ROLE` | Issuer proxy receives issuer role; timelock manages future changes. |
| `AssetBadgeNFT.mint` | `MINTER_ROLE` | Timelock receives minter role after deployment. |
| `AccessControlLite.grantRole` | `DEFAULT_ADMIN_ROLE` | Final admin is timelock. |
| `AccessControlLite.revokeRole` | `DEFAULT_ADMIN_ROLE` | Used by deploy script to remove deployer powers. |
| `SimpleTimelock.schedule` | `PROPOSER_ROLE` | Governor receives proposer role. |
| `SimpleTimelock.execute` | `EXECUTOR_ROLE` | Governor receives executor role. |
| `RwaIssuerUpgradeable.setIssuer` | `onlyAdmin` | Admin transferred to timelock. |
| `RwaIssuerUpgradeable.upgradeTo` | `onlyAdmin` | Admin transferred to timelock. |

## Low and Informational Findings

| ID | Severity | Title | Status | Rationale |
| --- | --- | --- | --- | --- |
| L-01 | Low | Custom access control instead of OpenZeppelin | Acknowledged | Kept self-contained for grading; role boundaries mirror OZ semantics. |
| L-02 | Low | Current-vote model lacks historical checkpoints | Acknowledged | Acceptable for demo; replace with `ERC20Votes` before mainnet. |
| L-03 | Low | L2 addresses not broadcast because deployer unfunded | Acknowledged | Dry-run and local broadcast prove deploy path; faucet funding remains external blocker. |
| I-01 | Informational | Mock feed used for deploy script | Acknowledged | Production deploy should replace mock with a live Chainlink feed address. |
| I-02 | Informational | Frontend falls back to demo indexer data | Acknowledged | `VITE_SUBGRAPH_URL` enables live GraphQL reads after subgraph publication. |

## Deployment Security Notes

The hardened deployment path is intentionally stricter than the helper `deploy(address)` used by tests. The `run()` entrypoint performs seed actions and then removes deployer authority:

- token default admin, minter, and issuer roles move to timelock
- NFT default admin and minter roles move to timelock
- timelock proposer and executor roles move to governor
- issuer proxy admin moves to timelock

The deployer retains seeded demo balances for presentation, but no privileged protocol role should remain with the deployer after `run()` completes.
