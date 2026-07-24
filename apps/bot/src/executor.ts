import { zeroAddress } from "viem";
import { sendBotTx } from "./chain.ts";
import { streamVaultsAbi } from "./abi/streamVaults.ts";
import { config } from "./config.ts";
import { logger } from "./logger.ts";
import type { Candidate, CloseDecision, SwapDecision } from "./discovery.ts";

export async function runSwap(decision: SwapDecision): Promise<void> {
  const { candidate, underlyingToken, targetToken, amountIn, minAmountOut, superAmountToDowngrade } =
    decision;

  const params = {
    superTokenIn: superAmountToDowngrade > 0n ? candidate.superToken : zeroAddress,
    superAmountIn: superAmountToDowngrade,
    tokenIn: underlyingToken,
    tokenOut: targetToken,
    fee: config.swapFeeTier,
    amountIn,
    minAmountOut,
  };

  try {
    const hash = await sendBotTx({
      address: config.streamVaultsAddress,
      abi: streamVaultsAbi,
      functionName: "executeSwap",
      args: [candidate.smartAccount, params],
    });
    logger.info("executeSwap sent", {
      smartAccount: candidate.smartAccount,
      amountIn: amountIn.toString(),
      minAmountOut: minAmountOut.toString(),
      hash,
    });
  } catch (err) {
    logger.warn("executeSwap skipped/failed", {
      smartAccount: candidate.smartAccount,
      reason: (err as Error).message,
    });
  }
}

export async function runClose(decision: CloseDecision): Promise<void> {
  const { candidate } = decision;
  try {
    const hash = await sendBotTx({
      address: config.streamVaultsAddress,
      abi: streamVaultsAbi,
      functionName: "closeStreamIfLow",
      args: [candidate.smartAccount, candidate.superToken],
    });
    logger.info("closeStreamIfLow sent", { smartAccount: candidate.smartAccount, hash });
  } catch (err) {
    logger.warn("closeStreamIfLow skipped/failed", {
      smartAccount: candidate.smartAccount,
      reason: (err as Error).message,
    });
  }
}

export type { Candidate };
