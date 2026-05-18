# Deployment Addresses

Network target: Arbitrum Sepolia first, then optional Optimism Sepolia, Base Sepolia, or zkSync Sepolia.

## Arbitrum Sepolia Status

Real L2 deployment is ready but not broadcast in this workspace because the available deployer had `0` Arbitrum Sepolia ETH at the time of preparation. The dry run against `https://sepolia-rollup.arbitrum.io/rpc` succeeded and estimated:

```text
Chain: 421614
Estimated gas used: 13,596,611
Estimated cost: 0.000543864453596611 ETH
```

Once a funded burner wallet is available, run the command in `docs/deployment-runbook.md` and replace the `TBD` rows below with explorer links.

| Contract | Arbitrum Sepolia Address | Verified |
| --- | --- | --- |
| GovernanceToken | `TBD` | No |
| Settlement Token | `TBD` | No |
| AssetBadgeNFT | `TBD` | No |
| RwaVault | `TBD` | No |
| ConstantProductAMM | `TBD` | No |
| Mock/Chainlink Feed | `TBD` | No |
| ChainlinkOracleAdapter | `TBD` | No |
| SimpleTimelock | `TBD` | No |
| ProtocolGovernor | `TBD` | No |
| ProtocolFactory | `TBD` | No |
| RwaIssuer Implementation | `TBD` | No |
| RwaIssuer Proxy | `TBD` | No |

## Local Deployment Evidence

The deployment script was broadcast successfully against local Anvil chain `31337`. Transaction artifact:

```text
broadcast/Deploy.s.sol/31337/run-latest.json
```

| Contract | Local Address | Check |
| --- | --- | --- |
| GovernanceToken | `0x5FbDB2315678afecb367f032d93F642f64180aa3` | Deployed |
| Settlement Token | `0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512` | Deployed |
| AssetBadgeNFT | `0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0` | Deployed |
| RwaVault | `0x0165878A594ca255338adfa4d48449f69242Eb8F` | Seeded |
| ConstantProductAMM | `0xa513E6E4b8f2a923D98304ec87F64353C4D5C853` | Seeded |
| Mock/Chainlink Feed | `0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9` | Deployed |
| ChainlinkOracleAdapter | `0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9` | Deployed |
| SimpleTimelock | `0x5FC8d32690cc91D4c39d9d3abcBD16989F875707` | Checked |
| ProtocolGovernor | `0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6` | Checked |
| ProtocolFactory | `0x8A791620dd6260079BF849Dc5567aDC3F2FdC318` | Deployed |
| RwaIssuer Implementation | `0x610178dA211FEF7D417bC0e6FeD39F05609AD788` | Deployed |
| RwaIssuer Proxy | `0xB7f8BC63BbcaD18155201308C8f3540b07f84F5e` | Admin transferred |

Post-deployment check:

```text
forge script script/PostDeployCheck.s.sol:PostDeployCheck --sig "check(address,address,address)" 0x5FbDB2315678afecb367f032d93F642f64180aa3 0x5FC8d32690cc91D4c39d9d3abcBD16989F875707 0x2279B7A0a67DB372996a5FaB50D91eAA73d2eBe6 --rpc-url http://127.0.0.1:8545

Return: true
```

## Post-Deployment Checklist

- Timelock delay is 2 days.
- Governor voting delay is 1 day.
- Governor voting period is 1 week.
- Governor quorum is 4%.
- Proposal threshold is 1%.
- Token issuer/admin roles are transferred to the timelock.
- Frontend addresses are updated.
- Subgraph addresses and start blocks are updated.
- Explorer verification links are added to this file.
