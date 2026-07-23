// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IAggregatorV3} from "../../src/core/interfaces/external/IAggregatorV3.sol";

/// @title MockAggregatorV3
/// @notice Settable Chainlink AggregatorV3 stub for unit tests.
contract MockAggregatorV3 is IAggregatorV3 {
	uint8 public decimals;
	int256 public answer;
	uint256 public updatedAt;
	uint80 public roundId;
	uint80 public answeredInRound;

	constructor(uint8 decimals_, int256 answer_) {
		decimals = decimals_;
		answer = answer_;
		updatedAt = block.timestamp;
		roundId = 1;
		answeredInRound = 1;
	}

	function setDecimals(uint8 d) external {
		decimals = d;
	}

	function setAnswer(int256 a) external {
		answer = a;
	}

	function setUpdatedAt(uint256 t) external {
		updatedAt = t;
	}

	function setRoundId(uint80 r) external {
		roundId = r;
	}

	function setAnsweredInRound(uint80 r) external {
		answeredInRound = r;
	}

	function latestRoundData()
		external
		view
		returns (uint80, int256, uint256, uint256, uint80)
	{
		return (roundId, answer, updatedAt, updatedAt, answeredInRound);
	}
}
