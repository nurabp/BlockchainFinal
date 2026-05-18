# L2 Deployment Runbook

Target network: Arbitrum Sepolia  
Chain ID: `421614`  
Public RPC fallback: `https://sepolia-rollup.arbitrum.io/rpc`

## Required Secrets

Use a funded burner wallet. The dry run estimated roughly `0.00054 ETH`; fund at least `0.002 ETH` on Arbitrum Sepolia to leave room for retries.

```powershell
$env:PRIVATE_KEY="0xYOUR_FUNDED_BURNER_PRIVATE_KEY"
$env:ARBITRUM_SEPOLIA_RPC_URL="https://sepolia-rollup.arbitrum.io/rpc"
$env:ETHERSCAN_API_KEY="YOUR_ETHERSCAN_V2_API_KEY"
```

## Dry Run

```powershell
forge script script/Deploy.s.sol:Deploy --rpc-url $env:ARBITRUM_SEPOLIA_RPC_URL
```

Expected result: `Script ran successfully` and a deployment struct with contract addresses.

## Broadcast and Verify

Etherscan V2 verification uses the chain-specific API URL for Arbitrum Sepolia.

```powershell
forge script script/Deploy.s.sol:Deploy `
  --rpc-url $env:ARBITRUM_SEPOLIA_RPC_URL `
  --broadcast `
  --verify `
  --verifier etherscan `
  --verifier-url "https://api.etherscan.io/v2/api?chainid=421614" `
  --etherscan-api-key $env:ETHERSCAN_API_KEY `
  --slow
```

After broadcast, copy the addresses from `broadcast/Deploy.s.sol/421614/run-latest.json` into:

- `docs/deployment-addresses.md`
- `frontend/src/App.jsx`
- `subgraph/subgraph.yaml`

## Post-Deployment Checks

Run the read-only verification script against the deployed token, timelock, and governor.

```powershell
forge script script/PostDeployCheck.s.sol:PostDeployCheck `
  --sig "check(address,address,address)" `
  <GovernanceToken> <SimpleTimelock> <ProtocolGovernor> `
  --rpc-url $env:ARBITRUM_SEPOLIA_RPC_URL
```

The deploy script seeds the protocol and then hardens ownership:

- mints demo RWA/USD to the deployer
- deposits RWA into the vault
- seeds AMM liquidity
- grants the governor proposer/executor roles on the timelock
- grants token/NFT admin roles to the timelock
- revokes deployer privileged token/NFT/timelock roles
- transfers issuer proxy admin to the timelock
