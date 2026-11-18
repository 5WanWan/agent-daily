# Agent Daily

A free daily check-in dApp for Agent ID holders — built for the Agent ID Hackathon.

- **Mint one soulbound badge** (free, gas only) — only if you hold an Agent ID.
- **Check in once a day** — your streak is stored on-chain, with a public leaderboard.
- **No fees, no payments, no admin.** The contract has no owner, no pause, no
  withdraw, and no function that can move your funds. It holds no user funds.

## Honest facts

- Free — you only pay BSC network gas. There is no fee, no token sale, no
  premium feature.
- The badge is soulbound: it can never be transferred to anyone.
- One badge per Agent ID holder. One check-in per 24 hours; missing a day resets
  your streak to 1.
- This is **not** a promise of rewards, returns, or income of any kind.
- The contract is open source (MIT) and will be verified on BscScan at deploy time.

## Contract

- Network: BSC mainnet (chain 56)
- Agent ID registry: `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`
- Agent Daily contract: **TBD — not deployed yet**
- BscScan: link added after deployment
- Live site: `https://5wanwan.github.io/agent-daily/` (after publishing)

## How to use

1. Open the live site and click **Connect Wallet** (standard wallet connection —
   no QR login, no session stored anywhere).
2. If you hold an Agent ID and have no badge yet, click **Mint Badge (free)** and
   confirm in your wallet.
3. Once you have a badge, click **Check in today** (once per 24h) and confirm.
4. Watch your streak and the top-10 leaderboard on the same page.

## For developers

```bash
forge build
forge test            # 18 tests, incl. soulbound + streak rules
forge test --gas-report
```

Local smoke test on Anvil (no real chain, no real funds):

```bash
anvil --port 8545
forge script script/DeployLocal.s.sol:DeployLocal \
  --rpc-url http://127.0.0.1:8545 \
  --private-key <anvil account 0 key> --broadcast
```

See `GAS.md` for measured gas costs and `BUILD-REPORT.md` for the build log.

## Hackathon

Submitted to the Agent ID Hackathon (Binance Wallet × BNB Chain).
Announcement: https://www.binance.com/en/support/announcement/detail/95f5dbe0ea674a48a739b59e046648bf

## License

MIT — see `LICENSE`.
