# Gas report — Agent Daily

Measured 18 Nov 2026. Two independent measurements agree exactly:
`forge test --gas-report` and real receipts from a local Anvil deployment
(`script/DeployLocal.s.sol`).

Gas price used for the BNB estimates: **0.05 gwei** (live BSC gas price checked
18 Nov 2026). Costs scale linearly with gas price — at 1 gwei multiply by 20,
at 5 gwei multiply by 100.

| Action | Gas | Cost @ 0.05 gwei (BNB) |
|---|---|---|
| Deploy `AgentDaily` | 635,078 | ~0.0000318 |
| `mintBadge()` (first mint, cold storage) | 141,213 | ~0.0000071 |
| `checkIn()` (first check-in, cold storage) | 114,549 | ~0.0000057 |
| `checkIn()` (repeat, warm storage, median) | 46,473 | ~0.0000023 |

**Deploy + 1 mint + 1 check-in ≈ 0.000045 BNB at 0.05 gwei.**

Notes:
- Contract size: 2,883 bytes (well under the 24,576-byte limit).
- `mintBadge` includes one external call to the Agent ID registry
  (`balanceOf`). `checkIn` is a single-contract call.
- View functions (`hasBadge`, `streakOf`, `lastCheckIn`, `totalCheckIns`,
  `badgeTokenId`, `totalBadges`, `totalCheckInsAll`) are free off-chain reads.
- For reference, at 1 gwei the deploy would cost ~0.00064 BNB and at 5 gwei
  ~0.0032 BNB — check the live gas price before deploying.
