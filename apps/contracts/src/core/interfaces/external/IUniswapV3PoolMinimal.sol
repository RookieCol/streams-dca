// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IUniswapV3PoolMinimal
/// @notice Minimal Uniswap v3 pool interface exposing only `observe`, used to
///         compute an arithmetic-mean tick (TWAP) as an independent price sanity
///         check.
interface IUniswapV3PoolMinimal {
	function observe(
		uint32[] calldata secondsAgos
	)
		external
		view
		returns (
			int56[] memory tickCumulatives,
			uint160[] memory secondsPerLiquidityCumulativeX128
		);
}
