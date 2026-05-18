# Gas Optimization Report

## Summary

The project uses optimizer runs set to 200 and `via_ir = true` in `foundry.toml`. The most important optimization demonstration is `YulMath.minYul`, benchmarked against `minSolidity`.

## Before and After Table

| Operation | Before | After | Notes |
| --- | ---: | ---: | --- |
| `minSolidity(7,4)` | baseline ternary | lower Yul path | `YulMath.minYul` |
| AMM swap | baseline reserve sync | cached `kBefore` | avoids extra getter calls |
| Vault withdraw | naive double transfer | CEI + single transfer | safer and simple |
| Oracle read | direct feed use | adapter with cached immutable feed | fewer storage reads |
| Factory proxy deployment | manual address tracking | deterministic CREATE2 prediction | cheaper operationally |
| Governance constants | storage params | constants | no storage load |

## L1 vs L2 Gas Comparison

| Operation | Ethereum Sepolia Estimate | Arbitrum Sepolia Estimate | Delta |
| --- | ---: | ---: | ---: |
| Mint backed tokens | 46,000 | 46,000 execution + lower fee | lower fee on L2 |
| Vault deposit | 105,000 | 105,000 execution + lower fee | lower fee on L2 |
| Vault withdraw | 118,000 | 118,000 execution + lower fee | lower fee on L2 |
| AMM add liquidity | 190,000 | 190,000 execution + lower fee | lower fee on L2 |
| AMM swap | 253,000 | 253,000 execution + lower fee | lower fee on L2 |
| Governance propose | 1,700,000 | 1,700,000 execution + lower fee | lower fee on L2 |

Real values should be replaced with post-deployment explorer estimates after L2 deployment.

## Benchmark Notes

Run:

```bash
forge test --gas-report
```

The tests `testYulMinMatchesSolidityMin`, `test055YulSqrt`, and `test056`-`test058` cover the Yul math utility.

