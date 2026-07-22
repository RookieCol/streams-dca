// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Types} from "../../libraries/Types.sol";

interface IStreamVaults {
	/// =====================
	/// ====== Events =======
	/// =====================

	event SmartAccountCreated(
		address indexed user,
		address indexed smartAccount
	);

	/// @notice Emitted when a user replaces their smart account with a fresh
	///         clone on the current implementation (e.g. after an impl upgrade).
	event SmartAccountRedeployed(
		address indexed user,
		address indexed oldSmartAccount,
		address indexed newSmartAccount
	);

	/// @notice Emitted whenever a stream is opened, updated, or closed through the gateway.
	/// @dev `previousRate == 0 && newRate > 0` -> opened. `newRate == 0` -> closed.
	event StreamUpdated(
		address indexed user,
		address indexed smartAccount,
		address indexed superToken,
		int96 previousRate,
		int96 newRate
	);

	event SwapExecuted(
		address indexed smartAccount,
		address indexed tokenIn,
		address indexed tokenOut,
		uint256 amountIn,
		uint256 amountOut
	);

	/// @notice Emitted by `onboard` when a user completes the one-shot setup.
	event Onboarded(
		address indexed user,
		address indexed smartAccount,
		address indexed superToken,
		uint256 underlyingAmountWrapped,
		uint256 superAmountMinted,
		int96 rate
	);

	/// @notice Emitted when the owner changes the per-SA swap cooldown.
	event SwapCooldownUpdated(uint256 cooldownBlocks);

	/// @notice Emitted when the bot pre-emptively closes a user's stream because
	///         the sender's spendable balance fell near the Superfluid buffer.
	/// @dev Closing while still solvent returns the full deposit to the sender,
	///      avoiding the liquidation penalty. `availableBalance` is the sender's
	///      spendable balance (excludes the locked `deposit`) at close time.
	event StreamAutoClosed(
		address indexed user,
		address indexed smartAccount,
		address indexed superToken,
		int256 availableBalance,
		uint256 deposit
	);

	/// @notice Emitted when the owner changes the auto-close threshold.
	event StreamCloseThresholdUpdated(uint256 thresholdBps);

	/// =====================
	/// ======= User ========
	/// =====================

	/// @notice Deploys a SmartAccountDCA clone owned by `msg.sender`. One per user.
	function createSmartAccount() external returns (address smartAccount);

	/// @notice Replaces the caller's smart account with a fresh clone on the
	///         current implementation. Old clone is detached (not destroyed);
	///         caller must withdraw/close it first. Reverts if none exists.
	function redeploySmartAccount() external returns (address smartAccount);

	/// @notice Sets the flowrate of a stream from `msg.sender` to their smart account.
	/// @dev Requires the user to have granted ACL permissions to this contract on `superToken`
	///      (e.g. via `CFAv1Forwarder.grantPermissions`). Setting `rate = 0` closes the stream.
	function setStream(
		address smartAccount,
		address superToken,
		int96 rate
	) external;

	/// @notice One-shot setup: pulls the pre-approved underlying token, wraps it
	///         into the SuperToken for `msg.sender`, deploys + configures their
	///         SmartAccountDCA and opens the stream.
	/// @dev Standard two-step onboarding, no permit / EIP-5792 batch involved:
	///      (tx1) the user calls `approve(underlying)` granting this contract an
	///      ERC20 allowance for `underlyingAmount`; (tx2) the user calls
	///      `grantPermissions` on the CFAv1Forwarder to make this contract a flow
	///      operator for `superToken`; (tx3) the user calls `onboard`.
	function onboard(
		address superToken,
		uint256 underlyingAmount,
		int96 rate,
		Types.UserRules calldata rules
	) external returns (address smartAccount);

	/// =====================
	/// ======== Bot ========
	/// =====================

	/// @notice Forwards a validated swap request to the smart account. Bot-only.
	/// @dev Validates: msg.sender == config.bot and that tokenIn/tokenOut are
	///      supported swap tokens (and distinct). The smart account routes the
	///      swap through the fixed config-set Uniswap v3 SwapRouter02 with the
	///      recipient hardcoded to itself and enforces the slippage check on the
	///      realized balance delta, so the bot cannot redirect output.
	function executeSwap(
		address smartAccount,
		Types.SwapParams calldata params
	) external returns (uint256 amountOut);

	/// @notice Pre-emptively closes a user's stream when the sender's spendable
	///         balance has fallen to within `streamCloseThresholdBps` of the
	///         Superfluid buffer (i.e. the stream is about to go critical).
	///         Bot-only. Closing while solvent returns the full deposit to the
	///         user and avoids the liquidation penalty. Reverts if the stream is
	///         not active (`STREAM_NOT_ACTIVE`) or not yet low (`STREAM_NOT_LOW`).
	function closeStreamIfLow(
		address smartAccount,
		address superToken
	) external returns (bool closed);

	/// =====================
	/// ====== Owner ========
	/// =====================

	/// @notice Sets the per-SA swap cooldown in blocks. Owner-only.
	function setSwapCooldown(uint256 cooldownBlocks) external;

	/// @notice Sets the auto-close threshold in bps of the buffer. Owner-only.
	///         `closeStreamIfLow` fires when the sender's spendable balance is
	///         at or below `thresholdBps` of the locked deposit. Max 10000.
	function setStreamCloseThreshold(uint256 thresholdBps) external;

	/// =====================
	/// ======= Views =======
	/// =====================

	function smartAccountOf(address user) external view returns (address);

	function userOf(address smartAccount) external view returns (address);

	function config() external view returns (address);

	function swapCooldownBlocks() external view returns (uint256);

	function lastSwapBlock(address smartAccount) external view returns (uint256);

	function streamCloseThresholdBps() external view returns (uint256);
}
