// Static mock data for the UI spike — deterministic (no Math.random/Date.now)
// so server and client render identically. Swap for real reads once the
// Celo-side streaming contracts exist.

export const TIME_RANGES = ["1D", "1W", "1M", "3M", "YTD", "1Y"] as const;
export type TimeRange = (typeof TIME_RANGES)[number];

export const balanceSeries = [
  382, 386, 384, 391, 397, 395, 402, 408, 405, 411, 418, 423, 420, 428, 434,
  431, 439, 446, 442, 451, 458, 455, 463, 470, 468, 477, 485, 481, 490, 496,
];

export const balanceUsd = 496.12;
export const balanceChangeToday = 3.08;
export const balanceChangePctToday = 0.62;
export const flowRatePerDay = 12.5;

export const allocation = [
  { label: "WBTC", pct: 54, color: "#F7931A" },
  { label: "WETH", pct: 31, color: "#627EEA" },
  { label: "cUSD buffer", pct: 15, color: "#C7CAD1" },
] as const;

export const streamCycle = {
  streamedUsd: 87.5,
  budgetUsd: 140,
  pct: 62,
  label: "Active",
};

// projection: 10 years, [low, high] band + a "most likely" line value
export const projectionYears = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
export const projectionBand = [
  { year: 1, low: 480, high: 560, likely: 512 },
  { year: 2, low: 520, high: 680, likely: 580 },
  { year: 3, low: 560, high: 820, likely: 660 },
  { year: 4, low: 600, high: 980, likely: 750 },
  { year: 5, low: 640, high: 1180, likely: 860 },
  { year: 6, low: 680, high: 1420, likely: 990 },
  { year: 7, low: 720, high: 1700, likely: 1140 },
  { year: 8, low: 760, high: 2040, likely: 1310 },
  { year: 9, low: 800, high: 2440, likely: 1500 },
  { year: 10, low: 840, high: 2920, likely: 1720 },
];
export const projectionHighlightYear = 5;
export const currentValueUsd = balanceUsd;

export const swapHistory = [
  { id: "1", date: "Jul 21", pair: "cUSD → WBTC", amountUsd: 12.5, status: "done" },
  { id: "2", date: "Jul 20", pair: "cUSD → WETH", amountUsd: 12.5, status: "done" },
  { id: "3", date: "Jul 19", pair: "cUSD → WBTC", amountUsd: 12.5, status: "done" },
  { id: "4", date: "Jul 18", pair: "cUSD → WBTC", amountUsd: 12.5, status: "done" },
  { id: "5", date: "Jul 17", pair: "cUSD → XAUt0", amountUsd: 12.5, status: "done" },
  { id: "6", date: "Jul 16", pair: "cUSD → WBTC", amountUsd: 12.5, status: "done" },
  { id: "7", date: "Jul 15", pair: "cUSD → WETH", amountUsd: 12.5, status: "done" },
] as const;

