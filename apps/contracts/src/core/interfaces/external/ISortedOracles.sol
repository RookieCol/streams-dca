// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title ISortedOracles
/// @notice Minimal Mento SortedOracles interface used as a fallback price source.
/// @dev `medianRate` returns (numerator, denominator) of a fixed-point rate. On
///      Celo mainnet (verified on-chain) the denominator is the Mento "fixidity"
///      unit (1e24), and numerator/denominator is the price of ONE CELO denominated
///      in the rate feed's quote (stable) token — e.g. the cUSD rate feed returns
///      CELO priced in cUSD (≈ CELO/USD, since cUSD is USD-pegged). It is NOT the
///      stable token's own USD price. See HybridPriceOracle._usdPrice.
interface ISortedOracles {
	function medianRate(
		address rateFeedId
	) external view returns (uint256 numerator, uint256 denominator);

	function medianTimestamp(
		address rateFeedId
	) external view returns (uint256);

	function numRates(address rateFeedId) external view returns (uint256);
}
