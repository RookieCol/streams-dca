# apps/bot

Off-chain executor bot for StreamVaults. Polls Celo for `SmartAccountDCA`
clones with an active Superfluid stream and, once enough underlying token has
accumulated, calls the bot-gated `StreamVaults.executeSwap` /
`closeStreamIfLow` on their behalf. See
`/Users/rookiecol/.claude/plans/analiza-cual-seria-el-jazzy-pebble.md` for the
full design rationale.

## Setup

```bash
# 1. Build the contracts once so ABIs exist to sync from.
pnpm --filter contracts build   # runs forge build

# 2. Generate apps/bot/src/abi/*.ts from apps/contracts/out/*.json
pnpm --filter bot sync-abis

# 3. Configure env
cp apps/bot/.env.example apps/bot/.env
# fill in RPC_URL, BOT_PRIVATE_KEY, STREAM_VAULTS_ADDRESS (from the Deploy.s.sol run)

# 4. Run
pnpm --filter bot dev
```

Re-run `sync-abis` any time the contracts change.

## ERC-8021 attribution

`ATTRIBUTION_CODE` in `.env` comes from registering this project at the
hackathon (`npx skills add https://celobuilders.xyz`, then submit project
name + GitHub repo + Telegram handle). Until it's set, the bot still runs and
sends real transactions — it just skips the attribution suffix (logs a single
warning). Once you have the code, set it and restart; every subsequent
`executeSwap`/`closeStreamIfLow` will carry the ERC-8021 tag.

## ERC-8004 agent registration

One-time, not part of the running bot:

```bash
# 1. Update apps/web/public/agent.json's `endpoints[0].address` to the bot's
#    real wallet address (derived from BOT_PRIVATE_KEY), and deploy apps/web
#    so the file is reachable at a public URL.
# 2. Set AGENT_METADATA_URI in .env to that public URL.
pnpm --filter bot register-agent
```

Logs the resulting `agentId` and transaction hash — link both in the
hackathon submission's X/Twitter post.

## Design notes

- Discovery is plain RPC polling (`getLogs` + view reads), not a subgraph —
  appropriate for the single USDT->WBTC route and a handful of demo accounts.
  No "last synced block" is persisted; a restart re-scans a fixed look-back
  window (`LOOKBACK_BLOCKS` in `src/index.ts`).
- The loop runs sequentially (not `Promise.all`) so the single bot key never
  races its own nonce.
- `minAmountOut` is read directly from the protocol's own `HybridPriceOracle`
  (`config.oracle().minAmountOut(...)`) — the same value the contract itself
  would derive as the trust-anchor floor, so the bot never needs its own price
  feed.
