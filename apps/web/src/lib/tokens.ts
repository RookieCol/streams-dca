// Single source of truth for the tokens the app offers.
// Hackathon happy path: DCA from USDT into WBTC — one clean, verified route
// (Uniswap v3 USDT/WBTC pool on Celo, Chainlink USDT/USD + BTC/USD price feeds).
// Other assets (WETH, XAUt0, cETH) are intentionally out of scope for now; see
// apps/contracts/docs/MIGRATION.md for the analysis and roadmap.

/// Currency the user streams in (the "sell" leg). Single token for now: USDT.
export const INPUT_CURRENCIES = ["USDT"] as const;
export type InputCurrency = (typeof INPUT_CURRENCIES)[number];
export const DEFAULT_INPUT_CURRENCY: InputCurrency = "USDT";

/// Token the user can DCA into (the "buy" leg). Single asset for now: WBTC.
export const TARGET_TOKENS = ["WBTC"] as const;
export type Asset = (typeof TARGET_TOKENS)[number];

/// Celo-mainnet addresses. Canonical across the project; the contract deploy
/// script whitelists these same addresses (setSupportedSwapToken) and wires
/// their Chainlink price feeds.
export const TOKEN_ADDRESS: Record<Asset | InputCurrency, `0x${string}`> = {
  WBTC: "0x8aC2901Dd8A1F17a1A4768A6bA4C3751e3995B2D",
  USDT: "0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e",
};

/// Per-token display metadata (chart colors).
export const TOKEN_COLOR: Record<Asset | InputCurrency, string> = {
  WBTC: "#F7931A", // bitcoin
  USDT: "#26A17B",
};

/// Default asset a new stream buys.
export const DEFAULT_ASSETS: Asset[] = ["WBTC"];

/// Targets available for a given input. Single-asset scope for now, so this just
/// returns the full target list; kept as a function so the UI stays unchanged as
/// more assets are added later.
export function targetsFor(_input: InputCurrency): Asset[] {
  return [...TARGET_TOKENS];
}
