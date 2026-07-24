import { config } from "./config.ts";
import { publicClient } from "./chain.ts";
import { discoverCandidates, evaluateClose, evaluateSwap } from "./discovery.ts";
import { runClose, runSwap } from "./executor.ts";
import { logger } from "./logger.ts";

// No persisted "last synced block" store: on restart this look-back window is
// used instead. Fine for a handful of hackathon-demo accounts; not a
// production design (see plan doc, open risk #4).
const LOOKBACK_BLOCKS = 200_000n;

let running = false;

async function tick() {
  if (running) {
    logger.warn("previous tick still running, skipping this interval");
    return;
  }
  running = true;
  try {
    const currentBlock = await publicClient.getBlockNumber();
    const fromBlock = currentBlock > LOOKBACK_BLOCKS ? currentBlock - LOOKBACK_BLOCKS : 0n;

    const candidates = await discoverCandidates(fromBlock);
    logger.info("tick start", { candidates: candidates.length, currentBlock: currentBlock.toString() });

    // Sequential, not Promise.all: a single bot key must not race its own nonce.
    for (const candidate of candidates) {
      const closeDecision = await evaluateClose(candidate);
      if (closeDecision) {
        await runClose(closeDecision);
        continue; // stream is being closed; no point evaluating a swap for it
      }

      const swapDecision = await evaluateSwap(candidate);
      if (swapDecision) {
        await runSwap(swapDecision);
      } else {
        logger.info("skip: not due", { smartAccount: candidate.smartAccount });
      }
    }
  } catch (err) {
    logger.error("tick failed", { reason: (err as Error).message });
  } finally {
    running = false;
  }
}

logger.info("bot starting", {
  chain: config.chainName,
  streamVaults: config.streamVaultsAddress,
  pollIntervalMs: config.pollIntervalMs,
  attributionEnabled: Boolean(config.attributionCode),
});

await tick();
setInterval(tick, config.pollIntervalMs);
