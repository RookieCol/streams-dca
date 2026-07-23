// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {StreamVaults} from "../src/core/StreamVaults.sol";
import {StreamVaultsConfig} from "../src/core/StreamVaultsConfig.sol";
import {SmartAccountDCA} from "../src/strategies/dca/SmartAccountDCA.sol";
import {HybridPriceOracle} from "../src/core/oracle/HybridPriceOracle.sol";

/// @title Deploy — StreamVaults DCA protocol wiring for Celo mainnet
/// @notice Hackathon happy path: a single verified route, **USDT -> WBTC**.
///         Deploys the oracle, smart-account implementation, and the two UUPS
///         proxies (Config + Vaults), whitelists USDT (input) + WBTC (target), and
///         wires their real Celo Chainlink USD feeds. No contract changes, no TWAP
///         fallback needed — both legs have live Chainlink feeds.
///
/// @dev Token model (mirrors apps/web/src/lib/tokens.ts):
///        - Pay leg (input):  USDT
///        - Buy leg (target):  WBTC
///      Both must be in `_supportedSwapTokens` (StreamVaults._executeSwap validates
///      tokenIn AND tokenOut). WETH / XAUt0 / cETH are out of scope — see
///      apps/contracts/docs/MIGRATION.md.
///
///      Run (dry-run):  forge script script/Deploy.s.sol --rpc-url celo
///      Broadcast:      forge script script/Deploy.s.sol --rpc-url celo --broadcast \
///                        --private-key $PRIVATE_KEY
///
///      Env (optional): BOT_ADDRESS, PROTOCOL_OWNER (both default to the broadcaster).
contract Deploy is Script {
	/// ===== Celo mainnet infra =====

	/// Uniswap v3 SwapRouter02 — the same router MiniPay's Squid multicall calls.
	address constant SWAP_ROUTER = 0x5615CDAb10dc425a742d643d949a7F474C01abc4;
	/// Superfluid CFAv1Forwarder (canonical).
	address constant CFA_FORWARDER = 0xcfA132E353cB4E398080B9700609bb008eceB125;
	/// Canonical Permit2 (reserved; not on the active swap path).
	address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

	uint256 constant MIN_ACCUMULATION_WINDOW = 86_400; // 1 day

	/// ===== Tokens =====

	address constant USDT = 0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e; // input
	address constant WBTC = 0x8aC2901Dd8A1F17a1A4768A6bA4C3751e3995B2D; // target

	/// ===== Chainlink USD feeds (Celo mainnet, verified on-chain, 8 dec, 240s) =====

	address constant USDT_USD_FEED = 0x5e37AF40A7A344ec9b03CCD34a250F3dA9a20B02;
	address constant BTC_USD_FEED = 0x128fE88eaa22bFFb868Bb3A584A54C96eE24014b;

	/// @dev Feed heartbeat is 240s; allow generous staleness for demo robustness.
	uint256 constant FEED_STALENESS = 1 hours;

	function run() external {
		address owner = vm.envOr("PROTOCOL_OWNER", msg.sender);
		address bot = vm.envOr("BOT_ADDRESS", msg.sender);

		vm.startBroadcast();

		// 1. Oracle + smart-account implementation.
		HybridPriceOracle oracle = new HybridPriceOracle(owner);
		SmartAccountDCA saImpl = new SmartAccountDCA();

		// 2. Config behind a UUPS proxy.
		StreamVaultsConfig cfgImpl = new StreamVaultsConfig();
		StreamVaultsConfig config = StreamVaultsConfig(
			address(
				new ERC1967Proxy(
					address(cfgImpl),
					abi.encodeCall(
						StreamVaultsConfig.initialize,
						(
							owner,
							bot,
							address(saImpl),
							PERMIT2,
							SWAP_ROUTER,
							address(oracle),
							CFA_FORWARDER,
							MIN_ACCUMULATION_WINDOW
						)
					)
				)
			)
		);

		// 3. Vaults gateway behind a UUPS proxy.
		StreamVaults vaultsImpl = new StreamVaults();
		StreamVaults vaults = StreamVaults(
			address(
				new ERC1967Proxy(
					address(vaultsImpl),
					abi.encodeCall(StreamVaults.initialize, (owner, address(config)))
				)
			)
		);

		// 4. Whitelist both legs (tokenIn AND tokenOut are validated).
		config.setSupportedSwapToken(USDT, true);
		config.setSupportedSwapToken(WBTC, true);

		// 5. Wire the Chainlink USD feeds — both legs have live Celo feeds, so the
		//    oracle's cross-price floor works with no TWAP fallback.
		oracle.setFeed(USDT, USDT_USD_FEED, FEED_STALENESS);
		oracle.setFeed(WBTC, BTC_USD_FEED, FEED_STALENESS);

		vm.stopBroadcast();

		console2.log("StreamVaultsConfig:", address(config));
		console2.log("StreamVaults:", address(vaults));
		console2.log("HybridPriceOracle:", address(oracle));
		console2.log("SmartAccountDCA impl:", address(saImpl));
	}
}
