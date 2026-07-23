# MiniPay Migration Analysis

Feasibility analysis for running **StreamVaults DCA** on Celo **inside the MiniPay wallet**.
This is a migration/feasibility note — see [`../README.md`](../README.md) for the protocol
reference.

## Objective

Run the StreamVaults DCA protocol end-to-end from MiniPay: a user onboards, streams cUSD,
and receives rule-bounded DCA swaps — without leaving the wallet.

## MiniPay constraints (hard limits)

MiniPay only broadcasts **normal transactions** via `eth_sendTransaction`. Everything else
that the reference design could lean on is unavailable.

| Capability | MiniPay | Consequence |
|---|---|---|
| Off-chain signatures (`personal_sign`, EIP-712) | ❌ | No `permit`, no meta-tx (ERC-2771 / Gelato / Biconomy), no Permit3 |
| EIP-7702 (type-4 tx) | ❌ | No account-abstraction batching at the wallet level |
| Call batching (EIP-5792 `wallet_sendCalls`) | ❌ | Multi-step setup cannot be a single confirmation |
| `feeCurrency` | cUSD only | User pays gas in cUSD; no CELO required (or usable) |
| Normal txs (`eth_sendTransaction`) | ✅ | The only interaction primitive available |

The chain (Celo) supports 7702 and the tokens support EIP-2612 `permit`; the blocker is the
**wallet**, not the protocol. Design around what the wallet exposes.

## What works (feasible)

- **All user actions as normal txs** — `approve`, `onboard`, `withdraw` are plain
  transactions MiniPay sends without issue.
- **On-chain logic bundled in a single `onboard()`** — one call still does
  `transferFrom` → wrap to SuperToken → create the user's smart account + set rules →
  open the stream. Atomicity is preserved on-chain even though the wallet can't batch.
- **Superfluid streaming** via the canonical `CFAv1Forwarder` on Celo mainnet — the ACL
  flow-operator grant is itself a normal tx.
- **DCA execution** by the off-chain executor bot — it uses its **own** key to send
  `executeSwap`, entirely unaffected by the wallet's signing limits.
- **Reuse of Celo mainnet infrastructure** — Uniswap v3 (`SwapRouter02`) and Superfluid are
  already deployed; no redeploy needed. Swaps go through the fixed router with `recipient`
  forced to the smart account, so a compromised executor cannot redirect output.
- **Kill switch** — the user revokes the flow-operator permission with one normal tx.

## What does not work (must drop or replace)

| Reference design | Why it fails on MiniPay | Migration |
|---|---|---|
| `permit`-based onboarding (`startStreamBot` + `Permit2612Sig`) | Needs a user EIP-712 signature | Replace with `approve()` + `onboard()` |
| Gasless UX via meta-transactions | Needs an off-chain signed request | Not possible — every user action is a real tx |
| Single-confirmation setup via EIP-7702 / EIP-5792 | Wallet sends neither type-4 txs nor batched calls | Not available — onboarding is multiple txs |

## Onboarding flow implication

Because the wallet cannot batch, and because the Superfluid flow-operator authorization is a
**user → forwarder** grant (`grantPermissions`, required before `setFlowrateFrom` per
`ICFAv1Forwarder`) — it authorizes the *contract*, so it cannot be folded into `onboard()`
nor batched with `approve` — onboarding on MiniPay is realistically **up to 3 sequential
user transactions**, each with `feeCurrency = cUSD`:

1. **`approve`** — approve the underlying (cUSD) to `StreamVaults`.
2. **grant flow-operator** — authorize `StreamVaults` as flow operator on the
   `CFAv1Forwarder` for the SuperToken.
3. **`onboard`** — the single atomic call: `transferFrom` → wrap to cUSDx → create smart
   account + set rules → `setFlowrateFrom`.

The flow-operator grant (step 2) is the piece that cannot be merged; steps 1 and 3 are
irreducible on their own.

## Other implications

- **cUSDx must be deployed.** No stablecoin SuperToken exists on Celo; a Wrapper Super Token
  (cUSDx, wrapping cUSD) is deployed via `SuperTokenFactory.createERC20Wrapper` before the
  protocol is configured.
- **cUSD covers both roles.** The user needs cUSD for the streamed principal *and* for gas
  (`feeCurrency`), so a single asset funds the entire flow.

## Open questions / risks

- **Onboarding UX** — 3 wallet confirmations is heavier than the reference's
  single-signature flow; confirm MiniPay surfaces the Superfluid ACL grant cleanly as a
  normal tx.
- **`feeCurrency` plumbing** — verify every tx (approve, grant, onboard, withdraw) is sent
  with `feeCurrency = cUSD` so users never need CELO.
- **Liquidity** — confirm Uniswap v3 depth on Celo for the target DCA pairs; keep Ubeswap as
  a whitelistable fallback target if needed.

---

## Buy-flow research findings (MiniPay parity)

Investigation into MiniPay's production "Buy" flow and what it takes to offer the same
assets (BTC / ETH / Gold) in this protocol.

### How MiniPay's buy actually works (on-chain analysis)

MiniPay's buy is **three plain EOA transactions** (nonces 0/1/2), all Celo **type-123
(CIP-64)** with `feeCurrency` set — i.e. gas paid in a stablecoin, no CELO needed. No
account abstraction, no ERC-4337, no permits.

1. `approve(SquidProxy, MAX)` on USDT.
2. `SquidProxy.fundAndRunMulticall(USDT, amount, calls[])` on the Squid Router proxy
   `0xce16F69375520ab01377ce7B88f5BA8C48F8D666`, where `calls[]` = `USDT.approve(SwapRouter,
   MAX)` + `SwapRouter02.exactInputSingle(USDT -> tokenOut, recipient = user)`.

The Uniswap router is `SwapRouter02 0x5615CDAb10dc425a742d643d949a7F474C01abc4` — **the same
router this protocol already uses**. Between assets, **only `tokenOut` changes**. The
"no visible signing" UX is the embedded MiniPay wallet auto-signing normal txs, not any
signature scheme this repo lacks. We deliberately keep our on-chain DCA (bot-triggered,
forced-recipient, oracle floor) instead of Squid's off-chain-generated calldata — Squid's
generic multicall + arbitrary calldata is exactly what our forced-recipient model rejects.

### Why the buy "feels like one tap" — first-party auto-signing (UX finding)

MiniPay's buy is **two on-chain transactions** (`approve` then `fundAndRunMulticall`), yet
the user only sees one action and **never confirms the approve**. This is not a contract
trick and the two txs are not merged — it is a **wallet-policy** effect:

- MiniPay is an **embedded / custodial wallet**: the signing key lives inside the app, so
  showing a confirmation is a **UX choice, not a cryptographic requirement**. The wallet can
  sign and broadcast an `eth_sendTransaction` with no prompt.
- The Buy Mini-Apps are **first-party** (built/blessed by MiniPay), so MiniPay **auto-signs
  their transactions silently**. One "Buy" tap → the app fires both txs → the wallet signs
  both without a modal. Two txs, one interaction.

**Implication for a third-party dapp (us):** we do **not** get silent auto-signing. MiniPay
surfaces a confirmation sheet per transaction for third-party apps, and it exposes no
batching (`wallet_sendCalls` / EIP-5792) or off-chain signatures (`permit` / Permit2) to
collapse them. So we cannot make our `approve` invisible the way the first-party Buy app
does — that privilege is not something code can grant itself.

**What we can do to approximate the one-tap feel:**
1. **`approve(spender, MAX_UINT256)` once** — same trick MiniPay uses; the approval stops
   reappearing on later actions (first action = approve + call, every later one = 1 call).
2. **Recurring buys run on the bot's key**, not the user's wallet → **zero user
   confirmations per buy** after onboarding (better than MiniPay's one-tap-per-buy).
3. The only visible cost is the **one-time onboarding** (`approve` → Superfluid
   flow-operator `grant` → `onboard`), which will show MiniPay confirmations for a
   third-party app.

**The only way to get MiniPay's actual silence** is to be integrated as an **official
MiniPay Mini-App** (allowlist / partnership, so the wallet extends auto-signing), or for
MiniPay to add EIP-5792 batching. Both are integration/product levers, not code changes.

### Celo liquidity map (Uniswap v3, verified via RPC)

| Target | Direct cUSD pool | Direct USDT pool |
|---|---|---|
| WETH  | ✅ cUSD@0.3% (liq 3.8e15) | ✅ USDT@0.01% (liq 1.7e11) |
| cETH  | ✅ cUSD@0.05% (liq 1.3e15) | ❌ USDT@0.3% liq **0** |
| WBTC  | ❌ none liquid | ✅ USDT@0.3% (liq 1.3e10) |
| XAUt0 | ❌ none liquid | ✅ USDT@0.3% (liq 2.8e10) |

MiniPay buys BTC/Gold from **USDT** precisely because there is no direct cUSD pool for them.

### Celo Chainlink coverage (verified on-chain)

Present (all verified live via `latestRoundData`): cUSD/USD `0xe38A…d048`, CELO/USD
`0x0568…Ab7e`, **BTC/USD** `0x128fE88eaa22bFFb868Bb3A584A54C96eE24014b`, **ETH/USD**
`0x1FcD30A73D67639c1cD89ff5746E7585731c083B`, **USDT/USD**
`0x5e37AF40A7A344ec9b03CCD34a250F3dA9a20B02` (plus USDC/USD, EUR/USD, and many fiat
pairs). **Absent: XAU/USD (gold).** So WBTC and WETH can be priced from Chainlink
directly; **XAUt0 cannot** (`HybridPriceOracle._usdPrice` needs a USD price for both
legs).

### Current scope decision (hackathon)

Ship the single **USDT → WBTC** route (Bitcoin — the MiniPay flagship): one liquid pool
(the exact one MiniPay uses) + live Chainlink feeds on both legs (USDT/USD, BTC/USD) →
the existing cross-price oracle floor works with **zero contract changes**. Wired in
`script/Deploy.s.sol`. WETH is equally feasible (ETH/USD exists) but out of scope to keep
one clean path; cETH is dropped (no liquid USDT pool, redundant with WETH).

### Deferred — enabling XAUt0 (Gold), needs oracle work

Adding WETH later is trivial (has a Chainlink feed). **XAUt0 is the one that needs oracle
work**: XAU/USD is absent on Celo Chainlink, so it can't be priced cross-feed. The blocker
is the price source, not liquidity (a USDT/XAUt0 pool exists). Two options:

- **TWAP-primary (fast, no deps):** reuse the existing `_twapQuote` in
  `HybridPriceOracle` to quote the USDT/asset pool directly when no USD feed exists.
  Weakness: the TWAP comes from the same pool being swapped → manipulable; mitigate with a
  long window + the deviation guard + the bot's `minAmountOut`.
- **Pyth (robust, production):** Pyth is on Celo (`0xff1a0f4744e8582DF1aE09D5611b887B6a12925C`,
  legacy "Not upgraded" contract — verify before use) and has BTC/USD `0xe62df6c8…b43`,
  ETH/USD, XAU/USD, USDT/USD. Pull model: the bot fetches a signed `updateData` from Hermes,
  `executeSwap` becomes `payable` and calls `updatePriceFeeds{value: getUpdateFee}` then
  reads `getPriceNoOlderThan(id, maxAge)` → `Price{price, conf, expo, publishTime}`. Use
  conf-adjusted prices (`price − k·conf` for tokenOut). Independent of the pool, so keep the
  Uniswap TWAP as the sanity band to catch wrapped-token depeg (XAUt0 ≠ XAU, cETH ≠ ETH —
  Pyth alone does not solve this). Cost: payable plumbing through
  `StreamVaults.executeSwap → SmartAccountDCA.executeSwap`, bot must hold native CELO for
  fees, added Wormhole guardian trust.

Verdict: **Pyth-primary + pool-TWAP sanity** is the production choice and fits the existing
primary→sanity structure; TWAP-primary is a valid faster bridge if the same-pool caveat is
acceptable.

### Roadmap / why the scope is small right now

The target vision is the **full MiniPay-promoted set — BTC + ETH + Gold** — all bought from
USDT through the same single-hop `exactInputSingle`, exactly like MiniPay (only `tokenOut`
changes). We deliberately **reduced the hackathon scope to BTC (WBTC) only** because it is
the one asset that ships with **zero contract changes and zero new dependencies** (live
Chainlink BTC/USD + USDT/USD on Celo). The path to the rest is already scoped:

1. **WETH (Ether)** — add-only: whitelist it + wire the existing ETH/USD feed. No contract
   change. Can land immediately post-hackathon.
2. **XAUt0 (Gold)** — needs the oracle work above (TWAP-primary now, or Pyth for
   production) since XAU/USD is absent on Celo Chainlink.
3. **Frontend real tx** — wire `approve` + `onboard` via viem with `feeCurrency = USDT`
   (needs the USDTx SuperToken deployed) so the demo shows a live MiniPay transaction.

Nothing here changes the architecture — it is all configuration + the one oracle extension
for gold.
