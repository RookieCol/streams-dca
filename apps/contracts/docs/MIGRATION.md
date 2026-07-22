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
