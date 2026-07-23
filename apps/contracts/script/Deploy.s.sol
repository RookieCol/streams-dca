// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {StreamVaults} from "../src/core/StreamVaults.sol";
import {StreamVaultsConfig} from "../src/core/StreamVaultsConfig.sol";
import {SmartAccountDCA} from "../src/strategies/dca/SmartAccountDCA.sol";
import {HybridPriceOracle} from "../src/core/oracle/HybridPriceOracle.sol";

/// @title Deploy — StreamVaults DCA protocol wiring for Celo mainnet
/// @notice Deploys the oracle, smart-account implementation, and the two UUPS
///         proxies (Config + Vaults), then whitelists the pay-leg currencies and
///         the buy-leg investment assets and registers their oracle price sources.
///
/// @dev Token model (canonical, mirrors apps/web/src/lib/tokens.ts):
///        - Pay leg (input, "sell"):  cUSD, USDT, USDC, CELO
///        - Buy leg (target, "buy"):  XAUt0, WETH, WBTC, cETH  (investment assets only)
///      Both legs must be in `_supportedSwapTokens`; the swap validates tokenIn AND
///      tokenOut against it (StreamVaults._executeSwap).
///
///      Run (dry-run, no broadcast):
///        forge script script/Deploy.s.sol --rpc-url celo
///      Broadcast:
///        forge script script/Deploy.s.sol --rpc-url celo --broadcast \
///          --private-key $PRIVATE_KEY
///
///      Env (all optional; sensible Celo-mainnet defaults below):
///        BOT_ADDRESS      off-chain executor key (defaults to broadcaster)
///        PROTOCOL_OWNER   owner of Config/Vaults/Oracle (defaults to broadcaster)
contract Deploy is Script {
	/// =====================
	/// == Celo mainnet infra
	/// =====================

	/// Uniswap v3 SwapRouter02 — the same router MiniPay's Squid multicall calls.
	address constant SWAP_ROUTER = 0x5615CDAb10dc425a742d643d949a7F474C01abc4;
	/// Superfluid CFAv1Forwarder (canonical).
	address constant CFA_FORWARDER = 0xcfA132E353cB4E398080B9700609bb008eceB125;
	/// Canonical Permit2 (reserved; not on the active swap path).
	address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
	/// Mento SortedOracles (fallback price source; CELO-quoted only).
	address constant MENTO_SORTED_ORACLES = 0xefB84935239dAcdecF7c5bA76d8dE40b077B7b33;

	uint256 constant MIN_ACCUMULATION_WINDOW = 86_400; // 1 day

	/// =====================
	/// == Pay-leg tokens ===
	/// =====================

	address constant CUSD = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
	address constant USDT = 0x48065fbBE25f71C9282ddf5e1cD6D6A887483D5e;
	address constant USDC = 0xcebA9300f2b948710d2653dD7B07f33A8B32118C;
	address constant CELO = 0x471EcE3750Da237f93B8E339c536989b8978a438;

	/// =====================
	/// == Buy-leg tokens ===
	/// =====================

	address constant XAUT0 = 0xaf37E8B6C9ED7f6318979f56Fc287d76c30847ff;
	address constant WETH = 0x66803FB87aBd4aaC3cbB3fAd7C3aa01f6F3FB207;
	address constant WBTC = 0x8aC2901Dd8A1F17a1A4768A6bA4C3751e3995B2D;
	address constant CETH = 0x2DEf4285787d58a2f811AF24755A8150622f4361;

	/// @dev Max Chainlink staleness tolerated per feed (seconds).
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
		bytes memory cfgInit = abi.encodeCall(
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
		);
		StreamVaultsConfig config = StreamVaultsConfig(
			address(new ERC1967Proxy(address(cfgImpl), cfgInit))
		);

		// 3. Vaults gateway behind a UUPS proxy.
		StreamVaults vaultsImpl = new StreamVaults();
		bytes memory vaultsInit = abi.encodeCall(
			StreamVaults.initialize,
			(owner, address(config))
		);
		StreamVaults vaults = StreamVaults(
			address(new ERC1967Proxy(address(vaultsImpl), vaultsInit))
		);

		// 4. Whitelist both legs. `_executeSwap` checks tokenIn AND tokenOut.
		_whitelistTokens(config);

		// 5. Register oracle price sources for the buy-leg assets.
		_configureOracleSources(oracle);

		vm.stopBroadcast();

		console2.log("StreamVaultsConfig:", address(config));
		console2.log("StreamVaults:", address(vaults));
		console2.log("HybridPriceOracle:", address(oracle));
		console2.log("SmartAccountDCA impl:", address(saImpl));
	}

	/// @dev Owner-only; runs inside the broadcast as `owner == broadcaster`. If the
	///      owner is a separate multisig, run this block from that key instead.
	function _whitelistTokens(StreamVaultsConfig config) internal {
		// Pay leg
		config.setSupportedSwapToken(CUSD, true);
		config.setSupportedSwapToken(USDT, true);
		config.setSupportedSwapToken(USDC, true);
		config.setSupportedSwapToken(CELO, true);
		// Buy leg (investment assets only — no stablecoins are purchasable)
		config.setSupportedSwapToken(XAUT0, true);
		config.setSupportedSwapToken(WETH, true);
		config.setSupportedSwapToken(WBTC, true);
		config.setSupportedSwapToken(CETH, true);
	}

	/// @dev Registers the price source each buy-leg asset needs, otherwise
	///      `SmartAccountDCA.executeSwap` reverts NO_PRICE_SOURCE.
	///
	///      REQUIRED BEFORE MAINNET: fill the Chainlink feed addresses below (and/or
	///      a Uniswap v3 TWAP pool via `oracle.setTwapPool`). XAUt0 / WETH-Wormhole /
	///      WBTC-Celo / cETH do NOT have obvious Celo Chainlink feeds — these MUST be
	///      verified on-chain, not assumed. The Mento fallback is CELO-quoted and is
	///      only sound for CELO; do NOT map it for non-CELO tokens (see README caveat).
	///      Left as address(0) here so a swap fails loudly rather than mis-prices.
	function _configureOracleSources(HybridPriceOracle oracle) internal {
		oracle.setSortedOracles(MENTO_SORTED_ORACLES);

		// TODO(verify): Celo mainnet Chainlink USD aggregators for each asset.
		address xaut0UsdFeed = vm.envOr("FEED_XAUT0_USD", address(0));
		address wethUsdFeed = vm.envOr("FEED_WETH_USD", address(0));
		address wbtcUsdFeed = vm.envOr("FEED_WBTC_USD", address(0));
		address cethUsdFeed = vm.envOr("FEED_CETH_USD", address(0));

		if (xaut0UsdFeed != address(0)) oracle.setFeed(XAUT0, xaut0UsdFeed, FEED_STALENESS);
		if (wethUsdFeed != address(0)) oracle.setFeed(WETH, wethUsdFeed, FEED_STALENESS);
		if (wbtcUsdFeed != address(0)) oracle.setFeed(WBTC, wbtcUsdFeed, FEED_STALENESS);
		if (cethUsdFeed != address(0)) oracle.setFeed(CETH, cethUsdFeed, FEED_STALENESS);

		// The pay-leg stablecoins also need a USD price for the cross. cUSD/USDC/USDT
		// are $1-pegged; set their Chainlink feeds here too (env-supplied, verify).
		address cusdUsdFeed = vm.envOr("FEED_CUSD_USD", address(0));
		address usdcUsdFeed = vm.envOr("FEED_USDC_USD", address(0));
		address usdtUsdFeed = vm.envOr("FEED_USDT_USD", address(0));
		if (cusdUsdFeed != address(0)) oracle.setFeed(CUSD, cusdUsdFeed, FEED_STALENESS);
		if (usdcUsdFeed != address(0)) oracle.setFeed(USDC, usdcUsdFeed, FEED_STALENESS);
		if (usdtUsdFeed != address(0)) oracle.setFeed(USDT, usdtUsdFeed, FEED_STALENESS);
	}
}
