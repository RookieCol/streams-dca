// Single source of truth for the tokens the app offers, aligned with the
// Celo/MiniPay design (apps/contracts). Streamed input is wrapped to a
// SuperToken on-chain (e.g. cUSD -> cUSDx); target tokens are the assets MiniPay
// promotes for purchase (BTC, ETH, Gold). On-chain wiring (addresses + oracle
// price sources) is applied by the Foundry deploy/config scripts.

/// Currencies the user can stream in (the "sell" leg).
/// cUSD is the primary path (cUSDx SuperToken + MiniPay feeCurrency). USDT, USDC
/// and CELO are offered in the UI but each needs its own SuperToken wrapper
/// (USDTx / USDCx / CELOx) deployed + whitelisted on the contract side before it
/// works end-to-end (tracked as a follow-up).
export const INPUT_CURRENCIES = ["cUSD", "USDT", "USDC", "CELO"] as const;
export type InputCurrency = (typeof INPUT_CURRENCIES)[number];
export const DEFAULT_INPUT_CURRENCY: InputCurrency = "cUSD";

/// Tokens the user can DCA into (the "buy" leg) — the MiniPay-promoted assets:
/// Gold (XAUt0), Ether (WETH, Wormhole), Bitcoin (WBTC, Celo) and cETH.
export const TARGET_TOKENS = ["XAUt0", "WETH", "WBTC", "cETH"] as const;
export type Asset = (typeof TARGET_TOKENS)[number];

/// Celo-mainnet addresses. Canonical across the project; the contract deploy
/// scripts whitelist these same addresses (setSupportedSwapToken) and register
/// their oracle price sources.
export const TOKEN_ADDRESS: Record<Asset | InputCurrency, `0x${string}`> = {
  // Output / target assets (buy leg)
  XAUt0: "0xaf37E8B6C9ED7f6318979f56Fc287d76c30847ff",
  WETH: "0x66803FB87aBd4aaC3cbB3fAd7C3aa01f6F3FB207",
  WBTC: "0x8aC2901Dd8A1F17a1A4768A6bA4C3751e3995B2D",
  cETH: "0x2DEf4285787d58a2f811AF24755A8150622f4361",
  // Input / payment currencies (sell leg)
  cUSD: "0x765DE816845861e75A25fCA122bb6898B8B1282a",
  USDT: "0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e",
  USDC: "0xcebA9300f2b948710d2653dD7B07f33A8B32118C",
  CELO: "0x471EcE3750Da237f93B8E339c536989b8978a438",
};

/// Per-token display metadata (chart colors).
export const TOKEN_COLOR: Record<Asset | InputCurrency, string> = {
  XAUt0: "#E5B94E", // gold
  WETH: "#627EEA", // ethereum
  WBTC: "#F7931A", // bitcoin
  cETH: "#4E5CE6",
  cUSD: "#C7CAD1",
  USDT: "#26A17B",
  USDC: "#2775CA",
  CELO: "#00C2A8",
};

/// Default assets a new stream buys (MiniPay's flagship BTC + ETH).
export const DEFAULT_ASSETS: Asset[] = ["WBTC", "WETH"];

/// Targets selectable for a given input. Output and input sets are disjoint, so
/// the contract's same-token reject (E-06) can't be hit here, but we keep the
/// guard so the two lists can never accidentally overlap.
export function targetsFor(input: InputCurrency): Asset[] {
  return TARGET_TOKENS.filter((t) => (t as string) !== (input as string));
}
