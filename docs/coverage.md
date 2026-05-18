# Coverage Report

Generated command:

```bash
forge coverage --report summary
```

Latest local test result:

```text
104 passing tests
0 failing tests
```

Latest local coverage summary:

```text
Total including scripts and test helpers: 78.70% lines, 77.67% statements
src/ contracts only: 346/360 lines covered, approximately 96.11%
```

The scripts, fork helper interfaces, and intentionally vulnerable test helper reduce the global total. The course requirement is line coverage across `contracts/` / production contracts, which maps to this repo's `src/` directory.

Fork coverage evidence:

```text
test/ForkIntegrationTest.t.sol
3 passing fork tests against Ethereum mainnet:
- USDC metadata and whale balance
- Uniswap V2 router factory/WETH and WETH -> USDC quote
- Chainlink ETH/USD latestRoundData
```
