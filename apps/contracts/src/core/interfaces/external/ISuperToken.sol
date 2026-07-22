// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title ISuperToken (minimal)
/// @notice Minimal subset of the Superfluid SuperToken interface used by the
///         StreamVaults gateway and SmartAccountDCA. Declared locally to avoid
///         pulling in the full Superfluid dependency (same pattern used for
///         ICFAv1Forwarder and IPermit2).
/// @dev Only the functions this protocol calls are declared here.
interface ISuperToken {
	/// @notice Returns the address of the underlying ERC20 token wrapped by this
	///         SuperToken, or address(0) for a native SuperToken.
	function getUnderlyingToken() external view returns (address);

	/// @notice Returns the number of decimals of the underlying ERC20 token.
	function getUnderlyingDecimals() external view returns (uint8);

	/// @notice Wraps `amount` (SuperToken-denominated) of underlying into this
	///         SuperToken, crediting `to`.
	function upgradeTo(address to, uint256 amount, bytes calldata data) external;

	/// @notice Unwraps `amount` of this SuperToken back into the underlying token.
	function downgrade(uint256 amount) external;

	/// @notice Returns the real-time balance snapshot for `account`.
	function realtimeBalanceOfNow(
		address account
	)
		external
		view
		returns (
			int256 availableBalance,
			uint256 deposit,
			uint256 owedDeposit,
			uint256 timestamp
		);
}
