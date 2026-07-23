// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

import {HybridPriceOracle} from "../src/core/oracle/HybridPriceOracle.sol";
import {Errors} from "../src/core/libraries/Errors.sol";

import {MockAggregatorV3} from "./mocks/MockAggregatorV3.sol";
import {MockSortedOracles} from "./mocks/MockSortedOracles.sol";
import {MockUniV3Pool} from "./mocks/MockUniV3Pool.sol";
import {MockERC20Decimals} from "./mocks/MockERC20Decimals.sol";

contract HybridPriceOracleTest is Test {
	address internal owner = makeAddr("owner");

	HybridPriceOracle internal oracle;

	// Tokens with distinct decimals.
	MockERC20Decimals internal usdc; // 6 decimals, $1
	MockERC20Decimals internal cusd; // 18 decimals, $1
	MockERC20Decimals internal celo; // 18 decimals, $0.5

	MockAggregatorV3 internal usdcFeed;
	MockAggregatorV3 internal cusdFeed;
	MockAggregatorV3 internal celoFeed;

	function setUp() public {
		oracle = new HybridPriceOracle(owner);

		usdc = new MockERC20Decimals(6);
		cusd = new MockERC20Decimals(18);
		celo = new MockERC20Decimals(18);

		usdcFeed = new MockAggregatorV3(8, 1e8); // $1
		cusdFeed = new MockAggregatorV3(8, 1e8); // $1
		celoFeed = new MockAggregatorV3(8, 5e7); // $0.5

		vm.startPrank(owner);
		oracle.setFeed(address(usdc), address(usdcFeed), 1 hours);
		oracle.setFeed(address(cusd), address(cusdFeed), 1 hours);
		oracle.setFeed(address(celo), address(celoFeed), 1 hours);
		vm.stopPrank();
	}

	/// Same decimals, equal prices: 10 cUSD -> ~10 CELO*2 ... here cUSD->cusd would
	/// be same token; use cUSD ($1, 18d) -> CELO ($0.5, 18d): expect 2x out.
	function test_crossPrice_sameDecimals() public view {
		// 10 cUSD ($10) buys 20 CELO ($0.5 each). 0 slippage.
		uint256 out = oracle.minAmountOut(
			address(cusd),
			address(celo),
			10e18,
			0
		);
		assertEq(out, 20e18, "10 cUSD -> 20 CELO");
	}

	/// Mixed decimals: USDC (6d, $1) -> cUSD (18d, $1). 100 USDC -> 100 cUSD.
	function test_crossPrice_mixedDecimals() public view {
		uint256 out = oracle.minAmountOut(
			address(usdc),
			address(cusd),
			100e6,
			0
		);
		assertEq(out, 100e18, "100 USDC -> 100 cUSD");
	}

	/// Mixed decimals other direction: cUSD (18d) -> USDC (6d). 100 cUSD -> 100 USDC.
	function test_crossPrice_mixedDecimalsReverse() public view {
		uint256 out = oracle.minAmountOut(
			address(cusd),
			address(usdc),
			100e18,
			0
		);
		assertEq(out, 100e6, "100 cUSD -> 100 USDC");
	}

	/// Floor scales linearly with slippage: 100 bps => 99% of expected.
	function test_floorScalesWithSlippage() public view {
		uint256 expected = 100e18; // 100 USDC -> 100 cUSD at par
		uint256 at100 = oracle.minAmountOut(
			address(usdc),
			address(cusd),
			100e6,
			100
		);
		assertEq(at100, (expected * 9900) / 10_000, "99% at 100bps");

		uint256 at250 = oracle.minAmountOut(
			address(usdc),
			address(cusd),
			100e6,
			250
		);
		assertEq(at250, (expected * 9750) / 10_000, "97.5% at 250bps");
	}

	/// Stale Chainlink falls through to Mento fallback.
	function test_staleChainlink_fallsBackToMento() public {
		MockSortedOracles so = new MockSortedOracles();
		vm.startPrank(owner);
		oracle.setSortedOracles(address(so));
		// cUSD priced via Mento at $1: numerator/denominator = 1.
		oracle.setMentoFallback(address(cusd), address(cusd));
		vm.stopPrank();

		// Make the cUSD Chainlink feed stale.
		cusdFeed.setUpdatedAt(1);
		vm.warp(1 + 1 hours + 1);

		// USDC feed must also be fresh; refresh it.
		usdcFeed.setUpdatedAt(block.timestamp);

		// Mento feed: 1e24 / 1e24 = $1, fresh (set AFTER the warp).
		so.set(address(cusd), 1e24, 1e24, block.timestamp, 3);

		uint256 out = oracle.minAmountOut(
			address(usdc),
			address(cusd),
			100e6,
			0
		);
		assertEq(out, 100e18, "Mento fallback prices cUSD at $1");
	}

	/// When both Chainlink and Mento are unavailable, revert NO_PRICE_SOURCE.
	function test_noPriceSource_reverts() public {
		// cUSD feed stale, no Mento configured.
		cusdFeed.setUpdatedAt(1);
		vm.warp(1 + 1 hours + 1);
		usdcFeed.setUpdatedAt(block.timestamp);

		vm.expectRevert(Errors.NO_PRICE_SOURCE.selector);
		oracle.minAmountOut(address(usdc), address(cusd), 100e6, 0);
	}

	/// Mento configured but stale also reverts NO_PRICE_SOURCE.
	function test_mentoStale_reverts() public {
		MockSortedOracles so = new MockSortedOracles();
		vm.startPrank(owner);
		oracle.setSortedOracles(address(so));
		oracle.setMentoFallback(address(cusd), address(cusd));
		vm.stopPrank();

		cusdFeed.setUpdatedAt(1);
		vm.warp(1_000_000);
		usdcFeed.setUpdatedAt(block.timestamp);
		// Mento median timestamp far in the past -> stale.
		so.set(address(cusd), 1e24, 1e24, 1, 3);

		vm.expectRevert(Errors.NO_PRICE_SOURCE.selector);
		oracle.minAmountOut(address(usdc), address(cusd), 100e6, 0);
	}

	/// TWAP within the deviation band passes.
	function test_twap_withinBand_passes() public {
		// tick 0 => price 1:1 in RAW units. USDC(6d) vs cUSD(18d) have a huge raw
		// ratio, so tick 0 does NOT match the Chainlink cross for USDC/cUSD. Use
		// two 18-decimal tokens at $1 each so raw price == quote price.
		MockERC20Decimals a = new MockERC20Decimals(18);
		MockERC20Decimals b = new MockERC20Decimals(18);
		MockAggregatorV3 fa = new MockAggregatorV3(8, 1e8);
		MockAggregatorV3 fb = new MockAggregatorV3(8, 1e8);

		// tick 0 -> 1:1 quote for equal-decimal tokens.
		MockUniV3Pool pool = new MockUniV3Pool(0);

		vm.startPrank(owner);
		oracle.setFeed(address(a), address(fa), 1 hours);
		oracle.setFeed(address(b), address(fb), 1 hours);
		oracle.setTwapPool(address(a), address(b), address(pool), 1800, 100); // 1%
		vm.stopPrank();

		// Chainlink expects 100 b out; TWAP tick 0 also ~100 b. Within 1%.
		uint256 out = oracle.minAmountOut(address(a), address(b), 100e18, 0);
		assertApproxEqRel(out, 100e18, 1e16, "twap-consistent quote");
	}

	/// TWAP outside the deviation band reverts ORACLE_DEVIATION.
	function test_twap_overBand_reverts() public {
		MockERC20Decimals a = new MockERC20Decimals(18);
		MockERC20Decimals b = new MockERC20Decimals(18);
		MockAggregatorV3 fa = new MockAggregatorV3(8, 1e8);
		MockAggregatorV3 fb = new MockAggregatorV3(8, 1e8);

		// tick far from 0 -> TWAP price diverges massively from the $1:$1 Chainlink
		// cross, exceeding the 1% band.
		MockUniV3Pool pool = new MockUniV3Pool(20000);

		vm.startPrank(owner);
		oracle.setFeed(address(a), address(fa), 1 hours);
		oracle.setFeed(address(b), address(fb), 1 hours);
		oracle.setTwapPool(address(a), address(b), address(pool), 1800, 100); // 1%
		vm.stopPrank();

		vm.expectRevert(Errors.ORACLE_DEVIATION.selector);
		oracle.minAmountOut(address(a), address(b), 100e18, 0);
	}
}
