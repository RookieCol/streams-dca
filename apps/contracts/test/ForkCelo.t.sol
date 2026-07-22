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
import {Types} from "../src/core/libraries/Types.sol";

import {MockUniswapRouter, MockMintableERC20} from "./mocks/MockUniswapRouter.sol";

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

	uint8 constant SEMI_UPGRADABLE = 1;
	uint256 constant WINDOW = 86_400;

	address deployer = makeAddr("deployer");
	address bot = makeAddr("bot");
	address settlement = makeAddr("settlement");
	address user;

	StreamVaultsConfig config;
	StreamVaults vaults;
	SmartAccountDCA saImpl;
	address cusdx;

	MockUniswapRouter router;
	MockMintableERC20 tokenOut;

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

		StreamVaultsConfig cfgImpl = new StreamVaultsConfig();
		config = StreamVaultsConfig(
			address(
				new ERC1967Proxy(
					address(cfgImpl),
					abi.encodeCall(
						StreamVaultsConfig.initialize,
						(deployer, bot, address(saImpl), PERMIT2, address(router), CFA_FORWARDER, WINDOW)
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

		vm.startPrank(deployer);
		config.setSupportedSwapToken(CUSD, true);
		config.setSupportedSwapToken(address(tokenOut), true);
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
