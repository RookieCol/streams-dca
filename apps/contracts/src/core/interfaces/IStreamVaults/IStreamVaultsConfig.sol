// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IStreamVaultsConfig {
	/// =====================
	/// ====== Events =======
	/// =====================

	event BotUpdated(address indexed previousBot, address indexed newBot);

	event TargetWhitelistUpdated(address indexed target, bool allowed);

	event SwapTokenSupportUpdated(address indexed token, bool supported);

	event SmartAccountImplementationUpdated(
		address indexed previousImpl,
		address indexed newImpl
	);

	event Permit2Updated(
		address indexed previousPermit2,
		address indexed newPermit2
	);

	event SwapRouterUpdated(
		address indexed previousSwapRouter,
		address indexed newSwapRouter
	);

	event OracleUpdated(
		address indexed previousOracle,
		address indexed newOracle
	);

	event CfaForwarderUpdated(
		address indexed previousForwarder,
		address indexed newForwarder
	);

	/// @notice Emitted when the owner updates the minimum stream accumulation
	///         window used by `StreamVaults.onboard` to gate viable rates.
	event MinStreamAccumulationWindowUpdated(
		uint256 previousWindow,
		uint256 newWindow
	);

	/// =====================
	/// ===== Setters =======
	/// =====================

	function setBot(address newBot) external;

	function setAllowedTarget(address target, bool allowed) external;

	function setSupportedSwapToken(address token, bool supported) external;

	function setSmartAccountImplementation(address newImpl) external;

	function setPermit2(address newPermit2) external;

	/// @notice Sets the fixed Uniswap v3 SwapRouter02 used for all swaps. Owner-only.
	function setSwapRouter(address newSwapRouter) external;

	/// @notice Sets the hybrid price-floor oracle used to bound swap output. Owner-only.
	function setOracle(address newOracle) external;

	function setCfaForwarder(address newForwarder) external;

	/// @notice Updates the minimum accumulation window (in seconds) used by
	///         `StreamVaults.onboard` to validate that a stream rate
	///         can accumulate at least `rules.minTradeAmount` within the window.
	/// @dev Must be >= `MIN_ACCUMULATION_WINDOW` (see implementation).
	function setMinStreamAccumulationWindow(uint256 windowSeconds) external;

	/// =====================
	/// ======= Views =======
	/// =====================

	function bot() external view returns (address);

	function isAllowedTarget(address target) external view returns (bool);

	function isSupportedSwapToken(address token) external view returns (bool);

	function smartAccountImplementation() external view returns (address);

	function permit2() external view returns (address);

	/// @notice Fixed Uniswap v3 SwapRouter02 through which all swaps are routed.
	function swapRouter() external view returns (address);

	/// @notice Hybrid price-floor oracle used to derive the minimum swap output.
	function oracle() external view returns (address);

	function cfaForwarder() external view returns (address);

	/// @notice Minimum accumulation window in seconds. Default at deploy time: 86_400 (1 day).
	function minStreamAccumulationWindow() external view returns (uint256);
}
