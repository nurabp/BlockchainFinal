# RWA Governed Protocol

Final project for Blockchain Technologies 2: a full-stack RWA tokenization protocol with vault deposits, AMM liquidity, oracle pricing, timelock governance, subgraph mappings, tests, documentation, and a React frontend.

## What Is Implemented

| Requirement | Implementation |
| --- | --- |
| ERC20 voting token | `src/token/GovernanceToken.sol` |
| ERC721 asset badge | `src/token/AssetBadgeNFT.sol` |
| ERC4626-style vault | `src/vault/RwaVault.sol` |
| DeFi primitive | `src/amm/ConstantProductAMM.sol` |
| Chainlink-style oracle | `src/oracle/ChainlinkOracleAdapter.sol` |
| Governance + timelock | `src/governance/` |
| UUPS-style upgrade path | `src/upgrade/` |
| CREATE and CREATE2 factory | `src/factory/ProtocolFactory.sol` |
| Subgraph schema/mappings | `subgraph/` |
| React frontend | `frontend/` |
| Tests and docs | `test/`, `docs/` |

## Quick Start

```powershell
npm install
forge build
forge test --summary --no-match-contract ForkIntegrationTest
npm run frontend:build
```

## Local Demo

Run a fresh Anvil deployment and start the frontend:

```powershell
npm run local:demo
```

MetaMask network:

```text
Network name: Local Anvil
RPC URL: http://127.0.0.1:8545
Chain ID: 31337
Currency: ETH
```

Frontend URL:

```text
http://127.0.0.1:5173
```

## Current Evidence

```text
Deterministic Foundry tests: 101 passed, 0 failed
Frontend production build: passing
Slither high/medium scan: 0 findings
Production src coverage: approximately 96.11% lines
Arbitrum Sepolia dry-run: 13,596,611 gas
```

## Documentation

- Architecture: `docs/architecture.md`
- Audit report: `docs/audit-report.md`
- Coverage report: `docs/coverage.md`
- Gas report: `docs/gas-report.md`
- Deployment runbook: `docs/deployment-runbook.md`
- Final report: `docs/RWA_Governed_Protocol_Final_Report.docx`
- Presentation: `docs/RWA_Governed_Protocol_Final_Presentation.pptx`

## L2 Deployment Note

The L2 deployment path is prepared for Arbitrum Sepolia and other Sepolia L2s. A real broadcast requires a funded testnet deployer wallet and an Etherscan API key. The local Anvil deployment is fully automated for classroom demonstration.
