// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StreamVaults} from "../src/core/StreamVaults.sol";
import {StreamVaultsConfig} from "../src/core/StreamVaultsConfig.sol";
import {SmartAccountDCA} from "../src/strategies/dca/SmartAccountDCA.sol";
import {ISmartAccountDCA} from "../src/strategies/dca/interfaces/ISmartAccountDCA.sol";
import {ISuperToken} from "../src/core/interfaces/external/ISuperToken.sol";
import {HybridPriceOracle} from "../src/core/oracle/HybridPriceOracle.sol";
import {IHybridPriceOracle} from "../src/core/interfaces/IHybridPriceOracle.sol";
import {IAggregatorV3} from "../src/core/interfaces/external/IAggregatorV3.sol";
import {ISortedOracles} from "../src/core/interfaces/external/ISortedOracles.sol";
import {Errors} from "../src/core/libraries/Errors.sol";
import {Types} from "../src/core/libraries/Types.sol";

import {MockUniswapRouter, MockMintableERC20} from "./mocks/MockUniswapRouter.sol";
import {MockAggregatorV3} from "./mocks/MockAggregatorV3.sol";

/// @dev Test-side view of the real Superfluid SuperTokenFactory (auto-detect
///      decimals overload). Upgradability: NON_UPGRADABLE=0, SEMI_UPGRADABLE=1,
///      FULL_UPGRADABLE=2.
interface ISuperTokenFactory {
	function createERC20Wrapper(
		address underlyingToken,
		uint8 upgradability,
		string calldata name,
		string calldata symbol
	) external returns (address superToken);
}

/// @dev Extended forwarder view exposing the user-facing ACL grant used during
///      onboarding (the protocol's minimal interface only needs get/setFlowrate).
interface ICFAForwarderExt {
	function grantPermissions(address token, address flowOperator) external returns (bool);

	function getFlowrate(
		address token,
		address sender,
		address receiver
	) external view returns (int96);
}

/// @notice Fork integration test against REAL Celo mainnet Superfluid.
///         Deploys a real cUSD wrapper SuperToken, deploys the protocol, and
///         proves onboarding opens a real Superfluid stream. The swap leg uses a
///         controlled mock router (real cUSD-pair liquidity is unreliable) while
///         the SuperToken wrap/downgrade is REAL.
contract ForkCeloTest is Test {
	// Real Celo mainnet addresses.
	address constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;
	address constant CFA_FORWARDER = 0xcfA132E353cB4E398080B9700609bb008eceB125;
	address constant SUPERTOKEN_FACTORY = 0x36be86dEe6BC726Ed0Cbd170ccD2F21760BC73D9;
	address constant CUSD = 0x765DE816845861e75A25fCA122bb6898B8B1282a;
	address constant CELO = 0x471EcE3750Da237f93B8E339c536989b8978a438;

	// Real Celo mainnet oracle infrastructure.
	address constant CHAINLINK_CELO_USD =
		0x0568fD19986748cEfF3301e55c0eb1E729E0Ab7e;
	address constant CHAINLINK_CUSD_USD =
		0xe38A27BE4E7d866327e09736F3C570F256FFd048;
	address constant MENTO_SORTED_ORACLES =
		0xefB84935239dAcdecF7c5bA76d8dE40b077B7b33;

	uint8 constant SEMI_UPGRADABLE = 1;
	uint256 constant WINDOW = 86_400;
	uint256 constant FEED_STALENESS = 30 days;

	address deployer = makeAddr("deployer");
	address bot = makeAddr("bot");
	address settlement = makeAddr("settlement");
	address user;

	StreamVaultsConfig config;
	StreamVaults vaults;
	SmartAccountDCA saImpl;
	HybridPriceOracle oracle;
	address cusdx;

	MockUniswapRouter router;
	MockMintableERC20 tokenOut;
	MockAggregatorV3 tokenOutFeed;

	function setUp() public {
		vm.createSelectFork(vm.envOr("CELO_RPC_URL", string("https://forno.celo.org")));
		assertEq(block.chainid, 42220, "must fork Celo mainnet");
		user = makeAddr("user");
	}

	function _deployProtocol() internal {
		vm.startPrank(deployer);
		saImpl = new SmartAccountDCA();

		// Fixed swap router (mock DEX substituting real cUSD-pair liquidity).
		router = new MockUniswapRouter();

		// Hybrid oracle wired to the REAL Celo Chainlink feeds + Mento fallback.
		oracle = new HybridPriceOracle(deployer);
		oracle.setFeed(CUSD, CHAINLINK_CUSD_USD, FEED_STALENESS);
		oracle.setFeed(CELO, CHAINLINK_CELO_USD, FEED_STALENESS);
		oracle.setSortedOracles(MENTO_SORTED_ORACLES);

		StreamVaultsConfig cfgImpl = new StreamVaultsConfig();
		config = StreamVaultsConfig(
			address(
				new ERC1967Proxy(
					address(cfgImpl),
					abi.encodeCall(
						StreamVaultsConfig.initialize,
						(deployer, bot, address(saImpl), PERMIT2, address(router), address(oracle), CFA_FORWARDER, WINDOW)
					)
				)
			)
		);

		StreamVaults svImpl = new StreamVaults();
		vaults = StreamVaults(
			address(
				new ERC1967Proxy(
					address(svImpl),
					abi.encodeCall(StreamVaults.initialize, (deployer, address(config)))
				)
			)
		);
		vm.stopPrank();
	}

	/// @dev Optional override: comma-separated candidate cUSD holders to
	///      impersonate if `deal` cannot rewrite the Mento token's storage.
	/// @dev Give `to` `amount` of cUSD, trying vm.deal-for-tokens first and
	///      falling back to impersonating a known holder (via the CUSD_WHALE env
	///      var) if the Mento token's storage layout defeats the cheatcode.
	function _fundCusd(address to, uint256 amount) internal {
		deal(CUSD, to, amount);
		if (IERC20(CUSD).balanceOf(to) >= amount) return;

		address whale = vm.envOr("CUSD_WHALE", address(0));
		if (whale != address(0) && IERC20(CUSD).balanceOf(whale) >= amount) {
			vm.prank(whale);
			IERC20(CUSD).transfer(to, amount);
		}
		require(IERC20(CUSD).balanceOf(to) >= amount, "could not fund cUSD");
	}

	function _createWrapper() internal returns (address st) {
		st = ISuperTokenFactory(SUPERTOKEN_FACTORY).createERC20Wrapper(
			CUSD,
			SEMI_UPGRADABLE,
			"Super Celo Dollar",
			"cUSDx"
		);
		assertEq(ISuperToken(st).getUnderlyingToken(), CUSD, "wrapper underlying == cUSD");
	}

	function _rules() internal view returns (Types.UserRules memory r) {
		address[] memory t = new address[](1);
		t[0] = address(tokenOut);
		r = Types.UserRules({
			maxSlippageBps: 100,
			minTradeAmount: 1e6,
			settlementAddress: settlement,
			targetTokens: t
		});
	}

	/// End-to-end: real wrapper + real forwarder onboarding opens a real stream,
	/// then a real downgrade feeds a controlled swap that settles tokenOut.
	function test_fork_onboardAndSwap_realSuperfluid() public {
		_deployProtocol();
		cusdx = _createWrapper();

		uint256 amount = 100e18; // 100 cUSD (18 decimals)
		int96 rate = int96(1e12); // wei/sec

		_fundCusd(user, amount);
		assertGe(IERC20(CUSD).balanceOf(user), amount, "user funded");

		// Swap-leg mock (fixed router substitutes real Uniswap liquidity; the
		// router itself is set in config at deploy time).
		tokenOut = new MockMintableERC20("Wrapped Ether", "WETH");
		tokenOut.mint(address(router), 1_000e18);

		// Give the mock tokenOut a $1 feed so the oracle can price the cUSD->WETH
		// leg (the accrued cUSD is small, so a $1 quote keeps the floor far below
		// the 5e18 the mock router delivers).
		tokenOutFeed = new MockAggregatorV3(8, 1e8);

		vm.startPrank(deployer);
		config.setSupportedSwapToken(CUSD, true);
		config.setSupportedSwapToken(address(tokenOut), true);
		oracle.setFeed(address(tokenOut), address(tokenOutFeed), FEED_STALENESS);
		vm.stopPrank();

		// tx1: approve underlying; tx2: grant flow-operator on the REAL forwarder;
		// tx3: onboard.
		vm.startPrank(user);
		IERC20(CUSD).approve(address(vaults), amount);
		ICFAForwarderExt(CFA_FORWARDER).grantPermissions(cusdx, address(vaults));
		address sa = vaults.onboard(cusdx, amount, rate, _rules());
		vm.stopPrank();

		// The smart account exists and the REAL forwarder reports a live stream.
		assertTrue(sa != address(0), "sa deployed");
		assertEq(vaults.userOf(sa), user, "sa owner");
		int96 live = ICFAForwarderExt(CFA_FORWARDER).getFlowrate(cusdx, user, sa);
		assertEq(live, rate, "real Superfluid flowrate open");

		// Let the stream accrue real cUSDx into the smart account.
		vm.warp(block.timestamp + 2 days);
		uint256 accrued = IERC20(cusdx).balanceOf(sa);
		assertGt(accrued, 0, "stream accrued cUSDx into SA");

		// Swap leg: downgrade REAL cUSDx -> cUSD, route through the mock router,
		// settle tokenOut to the settlement address.
		uint256 outAmount = 5e18;
		router.configure(CUSD, address(tokenOut), outAmount, false);

		Types.SwapParams memory p = Types.SwapParams({
			superTokenIn: cusdx,
			superAmountIn: accrued,
			tokenIn: CUSD,
			tokenOut: address(tokenOut),
			fee: 3000,
			amountIn: accrued,
			minAmountOut: outAmount
		});

		vm.prank(bot);
		uint256 got = vaults.executeSwap(sa, p);

		assertEq(got, outAmount, "swap output measured");
		assertEq(tokenOut.balanceOf(settlement), outAmount, "tokenOut settled to user");
	}

	/// Probe: read the REAL Chainlink CELO/USD & cUSD/USD feeds and the REAL Mento
	/// SortedOracles median rate for cUSD, and log their shape so the Mento quote
	/// convention can be verified/pinned.
	function test_fork_probeRealOracleSources() public {
		(, int256 celoAns, , uint256 celoUpd, ) = IAggregatorV3(
			CHAINLINK_CELO_USD
		).latestRoundData();
		(, int256 cusdAns, , uint256 cusdUpd, ) = IAggregatorV3(
			CHAINLINK_CUSD_USD
		).latestRoundData();
		emit log_named_uint("chainlink CELO/USD decimals", IAggregatorV3(CHAINLINK_CELO_USD).decimals());
		emit log_named_int("chainlink CELO/USD answer", celoAns);
		emit log_named_uint("chainlink CELO/USD age (s)", block.timestamp - celoUpd);
		emit log_named_int("chainlink cUSD/USD answer", cusdAns);
		emit log_named_uint("chainlink cUSD/USD age (s)", block.timestamp - cusdUpd);

		// Mento SortedOracles: rate feed id for cUSD is the cUSD token address.
		ISortedOracles so = ISortedOracles(MENTO_SORTED_ORACLES);
		uint256 n = so.numRates(CUSD);
		emit log_named_uint("mento cUSD numRates", n);
		if (n > 0) {
			(uint256 num, uint256 den) = so.medianRate(CUSD);
			emit log_named_uint("mento cUSD medianRate numerator", num);
			emit log_named_uint("mento cUSD medianRate denominator", den);
			emit log_named_uint("mento cUSD median age (s)", block.timestamp - so.medianTimestamp(CUSD));
			// price (1e18) under our convention = num * 1e18 / den
			emit log_named_uint("mento cUSD price 1e18 (num/den)", (num * 1e18) / den);
		}

		assertGt(celoAns, 0, "CELO/USD positive");
		assertGt(cusdAns, 0, "cUSD/USD positive");
	}

	/// SECURITY on a real fork: compute the real oracle floor for a cUSD->CELO swap
	/// from the REAL Chainlink cUSD/USD and CELO/USD feeds, then prove a mock-router
	/// delivery BELOW the floor reverts and a delivery AT/above the floor passes.
	/// @dev The delivery leg uses a mock 18-decimal tokenOut priced with the REAL
	///      CELO/USD Chainlink feed. The real Celo GoldToken's `balanceOf` reverts
	///      under this fork state (the same reason the whole suite substitutes a
	///      mock router for real cUSD-pair liquidity), so the FLOOR is derived from
	///      real on-chain prices while the token transfer stays deterministic.
	function test_fork_realFloor_cusdToCelo() public {
		_deployProtocol();
		cusdx = _createWrapper();

		uint256 amount = 100e18; // 100 cUSD
		int96 rate = int96(1e12);

		_fundCusd(user, amount);

		// Mock CELO stand-in for the delivery leg (18 decimals like real CELO),
		// priced with the REAL CELO/USD Chainlink feed.
		tokenOut = new MockMintableERC20("Celo (mock delivery)", "CELO");
		tokenOut.mint(address(router), 1_000e18);

		vm.startPrank(deployer);
		config.setSupportedSwapToken(CUSD, true);
		config.setSupportedSwapToken(address(tokenOut), true);
		oracle.setFeed(address(tokenOut), CHAINLINK_CELO_USD, FEED_STALENESS);
		vm.stopPrank();

		vm.startPrank(user);
		IERC20(CUSD).approve(address(vaults), amount);
		ICFAForwarderExt(CFA_FORWARDER).grantPermissions(cusdx, address(vaults));
		address sa = vaults.onboard(cusdx, amount, rate, _rules2());
		vm.stopPrank();

		vm.warp(block.timestamp + 2 days);
		uint256 accrued = IERC20(cusdx).balanceOf(sa);
		assertGt(accrued, 0, "accrued cUSDx");

		// Real oracle floor for swapping `accrued` cUSD -> CELO at 100 bps, using
		// the REAL Chainlink cUSD/USD and CELO/USD prices.
		uint256 floor = IHybridPriceOracle(address(oracle)).minAmountOut(
			CUSD,
			address(tokenOut),
			accrued,
			100
		);
		assertGt(floor, 0, "real floor computed");
		emit log_named_uint("real cUSD->CELO floor (accrued)", floor);

		Types.SwapParams memory p = Types.SwapParams({
			superTokenIn: cusdx,
			superAmountIn: accrued,
			tokenIn: CUSD,
			tokenOut: address(tokenOut),
			fee: 3000,
			amountIn: accrued,
			minAmountOut: 1 // loosest executor bound
		});

		// Delivery BELOW the floor reverts even with minAmountOut == 1.
		router.configure(CUSD, address(tokenOut), floor - 1, false);
		vm.prank(bot);
		vm.expectRevert(Errors.INSUFFICIENT_OUTPUT.selector);
		vaults.executeSwap(sa, p);

		// Delivery AT the floor passes.
		router.configure(CUSD, address(tokenOut), floor, false);
		vm.prank(bot);
		uint256 got = vaults.executeSwap(sa, p);
		assertEq(got, floor, "at-floor delivery settles");
		assertEq(tokenOut.balanceOf(settlement), floor, "settled to user");
	}

	function _rules2() internal view returns (Types.UserRules memory r) {
		address[] memory t = new address[](1);
		t[0] = address(tokenOut);
		r = Types.UserRules({
			maxSlippageBps: 100,
			minTradeAmount: 1e6,
			settlementAddress: settlement,
			targetTokens: t
		});
	}

	/// Negative counterpart to the happy path and the single most migration-critical
	/// behavior: with the permit fallback removed, opening the stream depends ENTIRELY
	/// on the user having granted flow-operator ACL to this contract first. Here the
	/// user funds + approves the underlying (so the pull and wrap succeed) but does
	/// NOT call `grantPermissions`. onboard must therefore revert at the stream-open
	/// step (`setFlowrateFrom`) inside the REAL CFAv1Forwarder — proving the stream
	/// genuinely requires the prior grant rather than the contract silently succeeding.
	function test_fork_onboard_revertsWithoutGrant() public {
		_deployProtocol();
		cusdx = _createWrapper();

		uint256 amount = 100e18;
		int96 rate = int96(1e12);

		_fundCusd(user, amount);
		assertGe(IERC20(CUSD).balanceOf(user), amount, "user funded");

		// Deploy tokenOut so the rules are VALID: this ensures onboard proceeds
		// through the pull + wrap + SA init and can only fail at the stream-open
		// step, not on an unrelated early rules-validation revert.
		tokenOut = new MockMintableERC20("Wrapped Ether", "WETH");

		// tx1: approve underlying. Deliberately SKIP the grantPermissions tx.
		vm.startPrank(user);
		IERC20(CUSD).approve(address(vaults), amount);
		// No ICFAForwarderExt(CFA_FORWARDER).grantPermissions(...) here.
		// The real CFA rejects the operator-initiated flow create with
		// CFA_ACL_OPERATOR_NO_CREATE_PERMISSIONS() (selector 0xa3eab6ac). Pinning the
		// selector proves the revert is the missing ACL grant at setFlowrateFrom, not
		// an unrelated earlier failure.
		vm.expectRevert(bytes4(0xa3eab6ac));
		vaults.onboard(cusdx, amount, rate, _rules());
		vm.stopPrank();

		// No smart account/stream should have been left behind.
		assertEq(vaults.smartAccountOf(user), address(0), "no SA on failed onboard");
	}
}
