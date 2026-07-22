// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title ISwapRouter02
/// @notice Minimal interface for the Uniswap v3 SwapRouter02 `exactInputSingle`
///         entrypoint. SwapRouter02 pulls `tokenIn` from the caller via a plain
///         ERC20 allowance and delivers `tokenOut` to `recipient`.
/// @dev SwapRouter02's `exactInputSingle` has NO deadline field (unlike the
///      original SwapRouter). Do not add one.
interface ISwapRouter02 {
	struct ExactInputSingleParams {
		address tokenIn;
		address tokenOut;
		uint24 fee;
		address recipient;
		uint256 amountIn;
		uint256 amountOutMinimum;
		uint160 sqrtPriceLimitX96;
	}

	/// @notice Swaps `amountIn` of one token for as much as possible of another,
	///         delivered to `recipient`.
	function exactInputSingle(
		ExactInputSingleParams calldata params
	) external payable returns (uint256 amountOut);
}
