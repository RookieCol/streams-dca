// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ISortedOracles} from "../../src/core/interfaces/external/ISortedOracles.sol";

/// @title MockSortedOracles
/// @notice Settable Mento SortedOracles stub for unit tests.
contract MockSortedOracles is ISortedOracles {
	struct Feed {
		uint256 numerator;
		uint256 denominator;
		uint256 timestamp;
		uint256 rates;
	}

	mapping(address => Feed) public feeds;

	function set(
		address rateFeedId,
		uint256 numerator,
		uint256 denominator,
		uint256 timestamp,
		uint256 rates
	) external {
		feeds[rateFeedId] = Feed(numerator, denominator, timestamp, rates);
	}

	function medianRate(
		address rateFeedId
	) external view returns (uint256, uint256) {
		Feed memory f = feeds[rateFeedId];
		return (f.numerator, f.denominator);
	}

	function medianTimestamp(
		address rateFeedId
	) external view returns (uint256) {
		return feeds[rateFeedId].timestamp;
	}

	function numRates(address rateFeedId) external view returns (uint256) {
		return feeds[rateFeedId].rates;
	}
}
