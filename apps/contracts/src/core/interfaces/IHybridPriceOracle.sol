// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title IHybridPriceOracle
/// @notice Derives a trust-anchored minimum swap output from an on-chain price
///         source and the USER's configured max slippage. The executor can only
///         make the floor stricter, never looser.
interface IHybridPriceOracle {
	/// @notice Minimum acceptable `tokenOut` for swapping `amountIn` of `tokenIn`,
	///         after applying `maxSlippageBps` slippage to the oracle-derived
	///         expected output. Denominated in `tokenOut` native units.
	/// @param tokenIn Input token being sold.
	/// @param tokenOut Output token being bought.
	/// @param amountIn Amount of `tokenIn` sold, in `tokenIn` native units.
	/// @param maxSlippageBps User-configured max slippage in basis points.
	function minAmountOut(
		address tokenIn,
		address tokenOut,
		uint256 amountIn,
		uint16 maxSlippageBps
	) external view returns (uint256);
}
