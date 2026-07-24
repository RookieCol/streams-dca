// Minimal hand-written ABIs for external interfaces the bot reads directly
// (Superfluid SuperToken/CFAv1Forwarder, the hybrid price oracle, and a plain
// ERC20). These mirror apps/contracts/src/core/interfaces/external/*.sol and
// are not Foundry build artifacts, since those interfaces aren't the bot's own
// contracts.

export const superTokenAbi = [
  {
    type: "function",
    name: "getUnderlyingToken",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "address" }],
  },
  {
    type: "function",
    name: "getUnderlyingDecimals",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "", type: "uint8" }],
  },
  {
    type: "function",
    name: "realtimeBalanceOfNow",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [
      { name: "availableBalance", type: "int256" },
      { name: "deposit", type: "uint256" },
      { name: "owedDeposit", type: "uint256" },
      { name: "timestamp", type: "uint256" },
    ],
  },
  {
    type: "function",
    name: "balanceOf",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
] as const;

export const cfaV1ForwarderAbi = [
  {
    type: "function",
    name: "getFlowrate",
    stateMutability: "view",
    inputs: [
      { name: "token", type: "address" },
      { name: "sender", type: "address" },
      { name: "receiver", type: "address" },
    ],
    outputs: [{ name: "flowrate", type: "int96" }],
  },
] as const;

export const hybridPriceOracleAbi = [
  {
    type: "function",
    name: "minAmountOut",
    stateMutability: "view",
    inputs: [
      { name: "tokenIn", type: "address" },
      { name: "tokenOut", type: "address" },
      { name: "amountIn", type: "uint256" },
      { name: "maxSlippageBps", type: "uint16" },
    ],
    outputs: [{ name: "", type: "uint256" }],
  },
] as const;

export const erc20Abi = [
  {
    type: "function",
    name: "balanceOf",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "", type: "uint256" }],
  },
] as const;
