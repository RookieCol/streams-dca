// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IUniswapV3PoolMinimal} from "../../src/core/interfaces/external/IUniswapV3PoolMinimal.sol";

/// @title MockUniV3Pool
/// @notice Settable Uniswap v3 pool stub whose `observe` yields a chosen
///         arithmetic-mean tick over the requested window.
/// @dev For the standard two-element `[secondsAgo, 0]` query, the returned
///      cumulative delta is `tick * secondsAgo`, so `consult` recovers exactly
///      `tick`.
contract MockUniV3Pool is IUniswapV3PoolMinimal {
	int24 public tick;

	constructor(int24 tick_) {
		tick = tick_;
	}

	function setTick(int24 tick_) external {
		tick = tick_;
	}

	function observe(
		uint32[] calldata secondsAgos
	) external view returns (int56[] memory, uint160[] memory) {
		uint256 n = secondsAgos.length;
		int56[] memory tickCumulatives = new int56[](n);
		uint160[] memory spl = new uint160[](n);
		// Reference point is the OLDEST requested observation (secondsAgos[0]).
		int56 base = int56(int32(secondsAgos[0]));
		for (uint256 i; i < n; ++i) {
			int56 elapsed = base - int56(int32(secondsAgos[i]));
			tickCumulatives[i] = int56(tick) * elapsed;
			spl[i] = 0;
		}
		return (tickCumulatives, spl);
	}
}
