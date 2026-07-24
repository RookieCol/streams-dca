// One-off script: registers the bot as an ERC-8004 agent identity. Run once,
// not part of the continuous bot loop, to avoid minting a redundant second
// identity on every restart.
//
// Usage: pnpm --filter bot register-agent
import "dotenv/config";
import { publicClient, walletClient, account } from "../src/chain.ts";
import { logger } from "../src/logger.ts";
import { config } from "../src/config.ts";
import type { Address } from "viem";

// ERC-8004 Identity Registry addresses (verified 2026-07-24, docs.celo.org/build-on-celo/build-with-ai/8004).
const IDENTITY_REGISTRY: Record<"celo" | "celoSepolia", Address> = {
  celo: "0x8004A169FB4a3325136EB29fA0ceB6D2e539a432",
  celoSepolia: "0x8004A818BFB912233c491871b3d84c89A494BD9e",
};

const identityRegistryAbi = [
  {
    type: "function",
    name: "register",
    stateMutability: "nonpayable",
    inputs: [{ name: "agentURI", type: "string" }],
    outputs: [{ name: "agentId", type: "uint256" }],
  },
] as const;

async function main() {
  const agentURI = process.env.AGENT_METADATA_URI;
  if (!agentURI) throw new Error("Missing AGENT_METADATA_URI env var");

  const registry = IDENTITY_REGISTRY[config.chainName];
  logger.info("registering agent", { registry, agentURI, bot: account.address });

  const { result: expectedAgentId } = await publicClient.simulateContract({
    account,
    address: registry,
    abi: identityRegistryAbi,
    functionName: "register",
    args: [agentURI],
  });
  logger.info("simulated agentId", { expectedAgentId: expectedAgentId.toString() });

  const hash = await walletClient.writeContract({
    address: registry,
    abi: identityRegistryAbi,
    functionName: "register",
    args: [agentURI],
  });

  logger.info("register tx sent", { hash });
  const receipt = await publicClient.waitForTransactionReceipt({ hash });
  logger.info("register confirmed", { status: receipt.status, blockNumber: receipt.blockNumber.toString() });
}

main().catch((err) => {
  logger.error("register-agent failed", { reason: (err as Error).message });
  process.exitCode = 1;
});
