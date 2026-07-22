// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Types} from "../../../core/libraries/Types.sol";

interface ISmartAccountDCA {
	/// =====================
	/// ====== Events =======
	/// =====================

	event Initialized(address indexed owner, address indexed operator);

	event RulesUpdated(
		uint16 maxSlippageBps,
		uint256 minTradeAmount,
		address indexed settlementAddress,
		address[] targetTokens
	);

	/// @param router The fixed Uniswap v3 SwapRouter02 the swap was routed through.
	event Executed(
		address indexed router,
		address indexed tokenIn,
		address indexed tokenOut,
		uint256 amountIn,
		uint256 amountOut
	);

	event Withdrawn(address indexed token, address indexed to, uint256 amount);

	/// =====================
	/// ======== Init =======
	/// =====================

	/// @notice Initializes a freshly cloned smart account.
	/// @param owner_ End-user address that owns this smart account.
	/// @param operator_ Address allowed to call `executeSwap`. In this protocol, the StreamVaults gateway.
	function initialize(address owner_, address operator_) external;

	/// @notice One-shot initializer that sets owner, operator and trading rules
	///         atomically. Used by the StreamVaults aggregator entrypoint so the
	///         account is fully usable after a single tx.
	/// @param owner_ End-user address that owns this smart account.
	/// @param operator_ Address allowed to call `executeSwap`.
	/// @param rules_ Trading rules to apply at creation time.
	function initializeWithRules(
		address owner_,
		address operator_,
		Types.UserRules calldata rules_
	) external;

	/// =====================
	/// ======= Owner =======
	/// =====================

	/// @notice Sets or replaces the trading rules for this smart account. Owner-only.
	function setRules(Types.UserRules calldata rules_) external;

	/// @notice Withdraws an arbitrary token balance held by the smart account. Owner-only kill-switch.
	function withdraw(address token, uint256 amount, address to) external;

	/// @notice Withdraws the full balance of a token held by the smart account. Owner-only kill-switch.
	function withdrawAll(address token, address to) external;

	/// =====================
	/// ====== Operator =====
	/// =====================

	/// @notice Executes a single swap on behalf of the user. Operator-only.
	/// @dev Forced-recipient design: the swap is routed through the FIXED,
	///      config-set Uniswap v3 SwapRouter02 with `recipient` hardcoded to
	///      `address(this)`, and only the exact per-swap `amountIn` is approved.
	///      This makes it impossible for the operator/bot to redirect swap output.
	///      Implementation MUST:
	///      1. Optionally downgrade `superTokenIn` to obtain underlying `tokenIn`.
	///      2. Validate `tokenOut` is whitelisted in `UserRules.targetTokens`.
	///      3. Bound `amountIn` to the held balance and the user minimum trade size.
	///      4. forceApprove exactly `amountIn` of `tokenIn` to the fixed router,
	///         call `exactInputSingle` with recipient == address(this), then revoke.
	///      5. Measure the realized balance delta of `tokenOut` and require it >= `minAmountOut`.
	///      6. Forward the received `tokenOut` to `UserRules.settlementAddress`.
	function executeSwap(
		Types.SwapParams calldata params
	) external returns (uint256 amountOut);

	/// =====================
	/// ======= Views =======
	/// =====================

	function owner() external view returns (address);

	function operator() external view returns (address);

	function rules()
		external
		view
		returns (
			uint16 maxSlippageBps,
			uint256 minTradeAmount,
			address settlementAddress
		);

	function targetTokens() external view returns (address[] memory);

	function isTargetToken(address token) external view returns (bool);
}
