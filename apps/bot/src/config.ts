import "dotenv/config";
import type { Hex } from "viem";

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required env var: ${name}`);
  return value;
}

function requiredHex(name: string): Hex {
  const value = required(name);
  if (!value.startsWith("0x")) throw new Error(`Env var ${name} must be 0x-prefixed hex`);
  return value as Hex;
}

const chainName = process.env.CHAIN ?? "celo";
if (chainName !== "celo" && chainName !== "celoSepolia") {
  throw new Error(`Unsupported CHAIN "${chainName}", expected "celo" or "celoSepolia"`);
}

export const config = {
  chainName: chainName as "celo" | "celoSepolia",
  rpcUrl: required("RPC_URL"),
  botPrivateKey: requiredHex("BOT_PRIVATE_KEY"),
  streamVaultsAddress: requiredHex("STREAM_VAULTS_ADDRESS"),
  pollIntervalMs: Number(process.env.POLL_INTERVAL_MS ?? 90_000),
  attributionCode: process.env.ATTRIBUTION_CODE || undefined,
  swapFeeTier: Number(process.env.SWAP_FEE_TIER ?? 3_000),
};
