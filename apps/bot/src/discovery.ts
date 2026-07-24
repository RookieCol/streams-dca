import type { Address, AbiEvent } from "viem";
import { publicClient } from "./chain.ts";
import { config } from "./config.ts";
import { streamVaultsAbi } from "./abi/streamVaults.ts";
import { streamVaultsConfigAbi } from "./abi/streamVaultsConfig.ts";
import { smartAccountDCAAbi } from "./abi/smartAccountDCA.ts";
import { superTokenAbi, erc20Abi, hybridPriceOracleAbi } from "./abi/external.ts";
import { logger } from "./logger.ts";

const streamVaults = config.streamVaultsAddress;

export interface Candidate {
  smartAccount: Address;
  user: Address;
  superToken: Address;
}

export interface SwapDecision {
  candidate: Candidate;
  underlyingToken: Address;
  targetToken: Address;
  amountIn: bigint;
  minAmountOut: bigint;
  superAmountToDowngrade: bigint;
}

export interface CloseDecision {
  candidate: Candidate;
}

const smartAccountCreatedEvent = streamVaultsAbi.find(
  (e) => e.type === "event" && e.name === "SmartAccountCreated",
) as AbiEvent;
const streamUpdatedEvent = streamVaultsAbi.find(
  (e) => e.type === "event" && e.name === "StreamUpdated",
) as AbiEvent;

// Celo's public RPC (forno.celo.org) caps eth_getLogs at a 5000-block range
// per call, so any lookback wider than that must be paginated.
const GET_LOGS_CHUNK_BLOCKS = 5_000n;

async function getLogsChunked(params: {
  event: AbiEvent;
  args?: Record<string, unknown>;
  fromBlock: bigint;
}) {
  const currentBlock = await publicClient.getBlockNumber();
  const results: Awaited<ReturnType<typeof publicClient.getLogs>> = [];
  for (let start = params.fromBlock; start <= currentBlock; start += GET_LOGS_CHUNK_BLOCKS) {
    const end = start + GET_LOGS_CHUNK_BLOCKS - 1n > currentBlock ? currentBlock : start + GET_LOGS_CHUNK_BLOCKS - 1n;
    const chunk = await publicClient.getLogs({
      address: streamVaults,
      event: params.event,
      args: params.args,
      fromBlock: start,
      toBlock: end,
    });
    results.push(...chunk);
  }
  return results;
}

/** Discovers every SmartAccountDCA clone with a currently active stream. */
export async function discoverCandidates(fromBlock: bigint): Promise<Candidate[]> {
  const created = await getLogsChunked({ event: smartAccountCreatedEvent, fromBlock });

  const candidates: Candidate[] = [];
  for (const log of created) {
    const args = (log as unknown as { args: Record<string, unknown> }).args;
    const user = args.user as Address;
    const smartAccount = args.smartAccount as Address;

    // Most recent StreamUpdated tells us the currently active superToken/rate.
    const streamLogs = await getLogsChunked({
      event: streamUpdatedEvent,
      args: { smartAccount },
      fromBlock,
    });
    const latest = streamLogs.at(-1);
    const latestArgs = (latest as unknown as { args: Record<string, unknown> } | undefined)?.args;
    if (!latestArgs || (latestArgs.newRate as bigint) === 0n) continue; // no active stream

    candidates.push({ smartAccount, user, superToken: latestArgs.superToken as Address });
  }
  return candidates;
}

async function getOracleAddress(): Promise<Address> {
  const configAddress = (await publicClient.readContract({
    address: streamVaults,
    abi: streamVaultsAbi,
    functionName: "config",
  })) as Address;
  return (await publicClient.readContract({
    address: configAddress,
    abi: streamVaultsConfigAbi,
    functionName: "oracle",
  })) as Address;
}

/** Decides whether a candidate has accumulated enough underlying to swap right now. */
export async function evaluateSwap(candidate: Candidate): Promise<SwapDecision | null> {
  const { smartAccount, superToken } = candidate;

  const [rules, targetTokens, underlyingToken, underlyingDecimals, wrappedBalance] =
    await Promise.all([
      publicClient.readContract({
        address: smartAccount,
        abi: smartAccountDCAAbi,
        functionName: "rules",
      }) as Promise<readonly [number, bigint, Address]>,
      publicClient.readContract({
        address: smartAccount,
        abi: smartAccountDCAAbi,
        functionName: "targetTokens",
      }) as Promise<readonly Address[]>,
      publicClient.readContract({
        address: superToken,
        abi: superTokenAbi,
        functionName: "getUnderlyingToken",
      }) as Promise<Address>,
      publicClient.readContract({
        address: superToken,
        abi: superTokenAbi,
        functionName: "getUnderlyingDecimals",
      }) as Promise<number>,
      publicClient.readContract({
        address: superToken,
        abi: superTokenAbi,
        functionName: "balanceOf",
        args: [smartAccount],
      }) as Promise<bigint>,
    ]);

  const [maxSlippageBps, minTradeAmount] = rules;
  const targetToken = targetTokens[0];
  if (!targetToken) return null;

  const underlyingBalance = (await publicClient.readContract({
    address: underlyingToken,
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [smartAccount],
  })) as bigint;

  // SuperTokens always use 18 decimals; downgrading `wrappedBalance` (18dp)
  // yields `wrappedBalance / 10^(18 - underlyingDecimals)` of the underlying.
  const scale = 18 - underlyingDecimals;
  const downgradedEquivalent = scale > 0 ? wrappedBalance / 10n ** BigInt(scale) : wrappedBalance;

  const amountIn = underlyingBalance + downgradedEquivalent;
  if (amountIn < minTradeAmount) return null;

  const [cooldownBlocks, lastSwapBlock, currentBlock] = await Promise.all([
    publicClient.readContract({
      address: streamVaults,
      abi: streamVaultsAbi,
      functionName: "swapCooldownBlocks",
    }) as Promise<bigint>,
    publicClient.readContract({
      address: streamVaults,
      abi: streamVaultsAbi,
      functionName: "lastSwapBlock",
      args: [smartAccount],
    }) as Promise<bigint>,
    publicClient.getBlockNumber(),
  ]);
  if (cooldownBlocks > 0n && lastSwapBlock > 0n && currentBlock - lastSwapBlock < cooldownBlocks) {
    logger.info("skip: swap cooldown active", { smartAccount });
    return null;
  }

  const oracleAddress = await getOracleAddress();
  const minAmountOut = (await publicClient.readContract({
    address: oracleAddress,
    abi: hybridPriceOracleAbi,
    functionName: "minAmountOut",
    args: [underlyingToken, targetToken, amountIn, maxSlippageBps],
  })) as bigint;

  return {
    candidate,
    underlyingToken,
    targetToken,
    amountIn,
    minAmountOut,
    superAmountToDowngrade: wrappedBalance,
  };
}

/** Mirrors the on-chain `closeStreamIfLow` trigger to avoid wasted attempts. */
export async function evaluateClose(candidate: Candidate): Promise<CloseDecision | null> {
  const { smartAccount, superToken } = candidate;

  const [realtime, thresholdBps] = await Promise.all([
    publicClient.readContract({
      address: superToken,
      abi: superTokenAbi,
      functionName: "realtimeBalanceOfNow",
      args: [smartAccount],
    }) as Promise<readonly [bigint, bigint, bigint, bigint]>,
    publicClient.readContract({
      address: streamVaults,
      abi: streamVaultsAbi,
      functionName: "streamCloseThresholdBps",
    }) as Promise<bigint>,
  ]);

  const [availableBalance, deposit] = realtime;
  if (deposit === 0n) return null; // no active flow / no buffer locked
  const trigger = (deposit * thresholdBps) / 10_000n;
  if (availableBalance > trigger) return null;

  return { candidate };
}
