// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {StreamVaults} from "../src/core/StreamVaults.sol";
import {StreamVaultsConfig} from "../src/core/StreamVaultsConfig.sol";
import {SmartAccountDCA} from "../src/strategies/dca/SmartAccountDCA.sol";
import {HybridPriceOracle} from "../src/core/oracle/HybridPriceOracle.sol";
import {Types} from "../src/core/libraries/Types.sol";

import {MockERC20Permit} from "./mocks/MockERC20Permit.sol";
import {MockSuperToken} from "./mocks/MockSuperToken.sol";
import {MockCFAv1Forwarder} from "./mocks/MockCFAv1Forwarder.sol";
import {MockPermit2} from "./mocks/MockPermit2.sol";
import {MockUniswapRouter, MockMintableERC20} from "./mocks/MockUniswapRouter.sol";
import {MockAggregatorV3} from "./mocks/MockAggregatorV3.sol";

/// @notice Shared deployment fixture for the unit-test suite. Wires the protocol
///         up with mocks so behavior is deterministic and fork-free.
contract Base is Test {
	// Actors
	address internal deployer = makeAddr("deployer");
	address internal bot = makeAddr("bot");
	address internal user = makeAddr("user");
	address internal stranger = makeAddr("stranger");
	address internal settlement = makeAddr("settlement");

	// Protocol
	StreamVaultsConfig internal config;
	StreamVaults internal vaults;
	SmartAccountDCA internal saImpl;
	HybridPriceOracle internal oracle;

	// Mocks
	MockERC20Permit internal usdc; // underlying, 6 decimals
	MockSuperToken internal usdcx; // super token, 18 decimals
	MockCFAv1Forwarder internal forwarder;
	MockPermit2 internal permit2;
	MockUniswapRouter internal router;
	MockMintableERC20 internal weth; // tokenOut, 18 decimals
	MockAggregatorV3 internal usdcFeed; // USDC/USD, $1
	MockAggregatorV3 internal wethFeed; // WETH/USD, $2

	/// @dev Generous staleness so block-number rolls in tests never expire feeds.
	uint256 internal constant FEED_STALENESS = 365 days;

	uint256 internal constant WINDOW = 86_400; // 1 day
	uint256 internal constant USDC_AMOUNT = 200e6; // 200 USDC
	int96 internal constant RATE = int96(1e12); // wei/sec

	function _deployProtocol() internal {
		vm.startPrank(deployer);

		// Mocks
		usdc = new MockERC20Permit("USD Coin", "USDC", 6);
		usdcx = new MockSuperToken("Super USDC", "USDCx", address(usdc), 6);
		forwarder = new MockCFAv1Forwarder();
		permit2 = new MockPermit2();
		router = new MockUniswapRouter();
		weth = new MockMintableERC20("Wrapped Ether", "WETH");

		// SmartAccountDCA implementation (clone target)
		saImpl = new SmartAccountDCA();

		// Hybrid price oracle with mock Chainlink feeds: USDC=$1, WETH=$2, so a
		// 100 USDC (6-dec) swap expects 50 WETH (18-dec) out.
		oracle = new HybridPriceOracle(deployer);
		usdcFeed = new MockAggregatorV3(8, 1e8); // $1
		wethFeed = new MockAggregatorV3(8, 2e8); // $2
		oracle.setFeed(address(usdc), address(usdcFeed), FEED_STALENESS);
		oracle.setFeed(address(weth), address(wethFeed), FEED_STALENESS);

		// Config behind a UUPS proxy.
		StreamVaultsConfig cfgImpl = new StreamVaultsConfig();
		bytes memory cfgInit = abi.encodeCall(
			StreamVaultsConfig.initialize,
			(
				deployer,
				bot,
				address(saImpl),
				address(permit2),
				address(router),
				address(oracle),
				address(forwarder),
				WINDOW
			)
		);
		config = StreamVaultsConfig(
			address(new ERC1967Proxy(address(cfgImpl), cfgInit))
		);

		// Vaults behind a UUPS proxy.
		StreamVaults svImpl = new StreamVaults();
		bytes memory svInit = abi.encodeCall(
			StreamVaults.initialize,
			(deployer, address(config))
		);
		vaults = StreamVaults(address(new ERC1967Proxy(address(svImpl), svInit)));

		vm.stopPrank();
	}

	function _defaultRules() internal view returns (Types.UserRules memory r) {
		address[] memory targets = new address[](1);
		targets[0] = address(weth);
		r = Types.UserRules({
			maxSlippageBps: 100,
			minTradeAmount: 1e6,
			settlementAddress: settlement,
			targetTokens: targets
		});
	}
}
