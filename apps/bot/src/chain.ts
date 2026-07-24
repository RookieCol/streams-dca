import {
  createPublicClient,
  createWalletClient,
  http,
  encodeFunctionData,
  type Abi,
  type Address,
  type Hex,
} from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { celo, celoSepolia } from "viem/chains";
import { config } from "./config.ts";
import { appendAttributionSuffix } from "./attribution.ts";
import { logger } from "./logger.ts";

const chain = config.chainName === "celo" ? celo : celoSepolia;
export const account = privateKeyToAccount(config.botPrivateKey);

export const publicClient = createPublicClient({
  chain,
  transport: http(config.rpcUrl),
});

export const walletClient = createWalletClient({
  account,
  chain,
  transport: http(config.rpcUrl),
});

let warnedNoAttribution = false;

/**
 * Simulates then sends a bot transaction, appending the ERC-8021 attribution
 * suffix to the final broadcast calldata. Simulation always runs against the
 * unsuffixed calldata so revert-checks aren't affected by the extra bytes.
 */
export async function sendBotTx(params: {
  address: Address;
  abi: Abi;
  functionName: string;
  args: readonly unknown[];
}): Promise<Hex> {
  await publicClient.simulateContract({
    account,
    address: params.address,
    abi: params.abi,
    functionName: params.functionName,
    args: params.args,
  });

  let data = encodeFunctionData({
    abi: params.abi,
    functionName: params.functionName,
    args: params.args,
  });

  if (config.attributionCode) {
    data = appendAttributionSuffix(data, config.attributionCode);
  } else if (!warnedNoAttribution) {
    logger.warn("ATTRIBUTION_CODE not set; sending transactions without ERC-8021 tag");
    warnedNoAttribution = true;
  }

  return walletClient.sendTransaction({ to: params.address, data });
}
