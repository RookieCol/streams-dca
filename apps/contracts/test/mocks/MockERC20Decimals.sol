// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title MockERC20Decimals
/// @notice Bare token exposing only `decimals()` (all the price oracle reads).
contract MockERC20Decimals {
	uint8 public decimals;

	constructor(uint8 decimals_) {
		decimals = decimals_;
	}
}
