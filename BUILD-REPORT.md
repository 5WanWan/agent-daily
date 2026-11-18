# BUILD-REPORT — Agent Daily (18 Nov 2026)

Built per `../build-brief.md` (Jack's decision 18 Nov 21:28 WIB: idea 1 + idea 3
merged; idea 2 deferred). No mainnet/testnet deployment. No wallet, private key,
seed phrase, or credential was touched at any point.

## What was built

Work dir: `~/workspace/agent-id-hackathon/agent-daily/`

| File | What |
|---|---|
| `contracts/AgentDaily.sol` | Single contract, Solidity ^0.8.20. Soulbound ERC-721 badge (mint only, every transfer/approval reverts), daily check-in + on-chain streak. No admin/owner/pause/withdraw, no payable function, no fee. Reads Agent ID holder status from registry `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`. |
| `test/AgentDaily.t.sol` | 18 Foundry tests incl. a minimal mock Agent ID registry (mock only — real registry is never used in unit tests). |
| `script/DeployLocal.s.sol` | Local Anvil smoke-test script only. Not for any real chain. |
| `foundry.toml` | solc 0.8.30, optimizer on (200 runs), cancun. |
| `web/index.html` + `web/app.js` + `web/style.css` | Static frontend, no build step, no backend. ethers.js 5.7.2 via jsDelivr CDN. Connect wallet → Agent ID status → mint badge → check-in → countdown → leaderboard from `CheckedIn` events via public BSC RPC (chunked, 3 endpoints with fallback). Honest disclaimers on-page. |
| `README.md`, `LICENSE` (MIT), `GAS.md` | Docs. Contract address = TBD until deployment. |

## Test results — `forge test` (forge 1.9.0, solc 0.8.30)

**18 passed, 0 failed, 0 skipped.**

All brief-required cases pass: (a) non-holder mint reverts; (b) holder mint
succeeds, tokenId 1; (b2) second holder gets tokenId 2; (c) second mint reverts;
(d) `transferFrom` reverts; (d2) `safeTransferFrom` reverts; (d3)
`safeTransferFrom` with data reverts; (d4) `approve`/`setApprovalForAll`
revert; (e) check-in without badge reverts; (f) double check-in within 24h
reverts; (g) next-day check-in → streak 2; (g2) 3-day streak → 3;
(h) gap >48h → streak resets to 1; (h2) check-in at exactly +2 days resets
(spec: streak kept only if `< last + 2 days`); (i) all view functions correct;
plus event-emission checks, zero-address registry rejection, and
`ownerOf` unknown-token revert.

`forge build` succeeds. Only warnings are forge lint notes in the test file
(`block.timestamp` read across `vm.warp`) — harmless, no critical warnings.

## Gas (forge gas report + Anvil receipts agree exactly)

- Deploy: **635,078 gas** (contract 2,883 bytes)
- `mintBadge()` first mint: **141,213 gas**
- `checkIn()` first: **114,549 gas**; repeat (median): **46,473 gas**
- At 0.05 gwei: deploy ≈ 0.000032 BNB; deploy + 1 mint + 1 check-in ≈ **0.000045 BNB**
- Full table + scaling notes in `GAS.md`.

## Live smoke test — local Anvil (chain 31337, no real funds)

`forge script` broadcast 5 transactions, all mined with status success:
deploy mock registry (145,719 gas), mint mock Agent ID (66,263),
deploy AgentDaily (635,078), `mintBadge` (141,213), `checkIn` (114,549).
Verified afterwards with `cast call`: `hasBadge=true`, `badgeTokenId=1`,
`streakOf=1`, `totalBadges=1`, `totalCheckInsAll=1`, `ownerOf(1)=deployer`.
`transferFrom` reverts on-chain with the `Soulbound()` custom error.
A real `CheckedIn` event was captured in the logs.

Incident, fixed honestly: the first broadcast attempt failed with
"insufficient funds" because I typed the Anvil account-0 private key from
memory with one wrong character (`…f4f3ff80` instead of `…f4f2ff80`), which
derived to an unfunded address. I took the key from the Anvil log itself,
re-broadcast with `--start-fresh`, and everything mined. No real funds were
ever involved (local Anvil test keys only).

## Frontend checks done

- `node --check web/app.js`: syntax OK. `index.html` parses OK.
- All three files serve HTTP 200 from a local static server.
- ethers.js 5.7.2 UMD CDN reachable (HTTP 200).
- Event decoding verified in Node against the real Anvil `CheckedIn` log:
  user, streak=1, totalCheckIns=1, timestamp all decode correctly with the
  same ABI the page uses.

## NOT tested live (needs parent/Jack, stated honestly)

1. **Wallet connect in a real browser** — no live browser available to this
   builder. The connect/mint/check-in click flow is code-reviewed and uses the
   standard `window.ethereum` + ethers v5 pattern, but no real wallet has
   clicked through it yet.
2. **GitHub Pages publish** (`5WanWan/agent-daily`) — repo creation/publish
   is a browser task for the parent.
3. **Mainnet deployment + BscScan verification** — explicitly out of scope for
   this builder; needs Jack's BAW relogin + a small BNB top-up (see GAS.md;
   ~0.00005 BNB at current gas, but keep a margin for gas spikes).
4. **Leaderboard against the real registry/contract** — the contract is not
   deployed yet, so the page currently shows "Leaderboard unlocks after the
   contract is deployed." The log-scanning code itself was validated against
   the real Anvil log (see above).
5. **Real Agent ID registry as the gate** — unit tests use a mock registry by
   design (per brief). The registry address in the contract is the real one
   from the hackathon announcement; a mainnet fork test was not run.

## Red-line compliance

- No "Binance"/"BNB" in project, token, or domain names. UI says "BSC
  network gas" only where the brief explicitly requires the gas note.
- No QR login, no session storage, no auto-transactions, no approvals, no
  promises of returns anywhere (contract, UI, README).
- No credentials anywhere in the repo. No other project's code was read as a
  reference; the contract and frontend were written from the brief spec alone.
