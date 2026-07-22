// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

library Types {
	/// @notice Trading rules set by the smart account owner.
	/// @param maxSlippageBps Maximum slippage tolerated, in basis points (1 = 0.01%).
	/// @param minTradeAmount Minimum amount of underlying input token required to execute a swap.
	/// @param settlementAddress Address that receives the swap output token after each trade.
	/// @param targetTokens Whitelist of acceptable output tokens (e.g. WETH, WBTC).
	struct UserRules {
		uint16 maxSlippageBps;
		uint256 minTradeAmount;
		address settlementAddress;
		address[] targetTokens;
	}

	/// @notice Parameters for a single swap executed by the bot through the smart
	///         account. The swap is routed through the protocol's fixed,
	///         config-set Uniswap v3 SwapRouter02 with the recipient hardcoded to
	///         the smart account itself, so the bot cannot redirect output.
	/// @param superTokenIn SuperToken to downgrade to underlying before swapping. Use address(0) to skip downgrade.
	/// @param superAmountIn Amount of SuperToken to downgrade.
	/// @param tokenIn Underlying input token approved to and pulled by the router.
	/// @param tokenOut Expected output token (must be in UserRules.targetTokens).
	/// @param fee Uniswap v3 pool fee tier for the tokenIn/tokenOut pair (e.g. 500, 3000).
	/// @param amountIn Exact amount of tokenIn to swap this trade.
	/// @param minAmountOut Minimum amount of tokenOut delivered, enforced on the realized balance delta.
	struct SwapParams {
		address superTokenIn;
		uint256 superAmountIn;
		address tokenIn;
		address tokenOut;
		uint24 fee;
		uint256 amountIn;
		uint256 minAmountOut;
	}
}
