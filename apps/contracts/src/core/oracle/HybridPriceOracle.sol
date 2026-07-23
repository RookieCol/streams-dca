// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// third party
/// openzeppelin
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// local
/// interfaces
import {IHybridPriceOracle} from "../interfaces/IHybridPriceOracle.sol";
import {IAggregatorV3} from "../interfaces/external/IAggregatorV3.sol";
import {ISortedOracles} from "../interfaces/external/ISortedOracles.sol";
import {IUniswapV3PoolMinimal} from "../interfaces/external/IUniswapV3PoolMinimal.sol";
/// libraries
import {Errors} from "../libraries/Errors.sol";

/// @title HybridPriceOracle
/// @notice Hybrid on-chain price floor: Chainlink primary, Mento SortedOracles
///         fallback, and an optional Uniswap v3 TWAP sanity band. Derives a
///         minimum acceptable swap output from the USER's max slippage so a
///         compromised executor can never loosen the floor.
/// @dev Non-upgradeable, owner-configured. Reads only; performs no state changes
///      on the price sources.
contract HybridPriceOracle is IHybridPriceOracle, Ownable, Errors {
	using Math for uint256;

	/// =====================
	/// ====== Types ========
	/// =====================

	struct TwapCfg {
		address pool;
		uint32 secondsAgo;
		uint16 maxDeviationBps;
		bool set;
	}

	/// =====================
	/// ====== Storage ======
	/// =====================

	/// @notice Chainlink aggregator per token (token USD price feed).
	mapping(address => address) public feedOf;
	/// @notice Max staleness (seconds) tolerated for a token's Chainlink feed.
	mapping(address => uint256) public maxStalenessOf;
	/// @notice Mento rate-feed id per token, used when Chainlink is unavailable.
	mapping(address => address) public mentoRateFeedOf;
	/// @notice Mento SortedOracles contract.
	address public sortedOracles;
	/// @notice TWAP sanity config keyed by keccak256(tokenIn, tokenOut).
	mapping(bytes32 => TwapCfg) public twapOf;

	/// @dev Max staleness applied to the Mento median timestamp (seconds).
	uint256 public constant MENTO_MAX_STALENESS = 600;

	/// =====================
	/// ====== Events =======
	/// =====================

	event FeedUpdated(
		address indexed token,
		address indexed aggregator,
		uint256 maxStaleness
	);
	event MentoFallbackUpdated(
		address indexed token,
		address indexed rateFeedId
	);
	event SortedOraclesUpdated(address indexed sortedOracles);
	event TwapPoolUpdated(
		address indexed tokenIn,
		address indexed tokenOut,
		address pool,
		uint32 secondsAgo,
		uint16 maxDeviationBps
	);

	constructor(address owner_) Ownable(owner_) {}

	/// =====================
	/// ===== Setters =======
	/// =====================

	function setFeed(
		address token,
		address aggregator,
		uint256 maxStaleness
	) external onlyOwner {
		if (isZeroAddress(token)) revert INVALID_ADDRESS();
		feedOf[token] = aggregator;
		maxStalenessOf[token] = maxStaleness;
		emit FeedUpdated(token, aggregator, maxStaleness);
	}

	function setMentoFallback(
		address token,
		address rateFeedId
	) external onlyOwner {
		if (isZeroAddress(token)) revert INVALID_ADDRESS();
		mentoRateFeedOf[token] = rateFeedId;
		emit MentoFallbackUpdated(token, rateFeedId);
	}

	function setSortedOracles(address addr) external onlyOwner {
		sortedOracles = addr;
		emit SortedOraclesUpdated(addr);
	}

	function setTwapPool(
		address tokenIn,
		address tokenOut,
		address pool,
		uint32 secondsAgo,
		uint16 maxDeviationBps
	) external onlyOwner {
		if (isZeroAddress(tokenIn) || isZeroAddress(tokenOut)) {
			revert INVALID_ADDRESS();
		}
		twapOf[_pairKey(tokenIn, tokenOut)] = TwapCfg({
			pool: pool,
			secondsAgo: secondsAgo,
			maxDeviationBps: maxDeviationBps,
			set: pool != address(0)
		});
		emit TwapPoolUpdated(
			tokenIn,
			tokenOut,
			pool,
			secondsAgo,
			maxDeviationBps
		);
	}

	/// =====================
	/// ======= View ========
	/// =====================

	/// @inheritdoc IHybridPriceOracle
	function minAmountOut(
		address tokenIn,
		address tokenOut,
		uint256 amountIn,
		uint16 maxSlippageBps
	) external view returns (uint256) {
		// a. USD prices (1e18-scaled) for both legs.
		uint256 priceIn = _usdPrice(tokenIn);
		uint256 priceOut = _usdPrice(tokenOut);

		// b. Cross price -> expected tokenOut, adjusting for token decimals.
		//    expectedOut = amountIn * priceIn / priceOut * 10^decOut / 10^decIn
		uint256 decIn = IERC20Metadata(tokenIn).decimals();
		uint256 decOut = IERC20Metadata(tokenOut).decimals();
		uint256 expectedOut = Math.mulDiv(amountIn, priceIn, priceOut);
		expectedOut = Math.mulDiv(expectedOut, 10 ** decOut, 10 ** decIn);

		// c. Optional Uniswap v3 TWAP sanity band.
		TwapCfg memory cfg = twapOf[_pairKey(tokenIn, tokenOut)];
		if (cfg.set) {
			uint256 twapOut = _twapQuote(
				cfg.pool,
				cfg.secondsAgo,
				tokenIn,
				tokenOut,
				amountIn
			);
			uint256 diff = expectedOut > twapOut
				? expectedOut - twapOut
				: twapOut - expectedOut;
			// abs(cl - twap) * 10000 <= maxDeviationBps * cl
			if (diff * 10_000 > uint256(cfg.maxDeviationBps) * expectedOut) {
				revert ORACLE_DEVIATION();
			}
		}

		// d. Apply the user's slippage tolerance to the expected output.
		return Math.mulDiv(expectedOut, 10_000 - maxSlippageBps, 10_000);
	}

	/// =====================
	/// ====== Internal =====
	/// =====================

	function _pairKey(
		address tokenIn,
		address tokenOut
	) internal pure returns (bytes32) {
		return keccak256(abi.encodePacked(tokenIn, tokenOut));
	}

	/// @dev USD price of `token`, scaled to 1e18. Chainlink primary, Mento
	///      fallback. Reverts NO_PRICE_SOURCE if neither yields a fresh price.
	function _usdPrice(address token) internal view returns (uint256) {
		// --- Chainlink primary ---
		address feed = feedOf[token];
		if (feed != address(0)) {
			(
				uint80 roundId,
				int256 answer,
				,
				uint256 updatedAt,
				uint80 answeredInRound
			) = IAggregatorV3(feed).latestRoundData();
			bool fresh = answer > 0 &&
				answeredInRound >= roundId &&
				updatedAt != 0 &&
				block.timestamp - updatedAt <= maxStalenessOf[token];
			if (fresh) {
				uint8 feedDec = IAggregatorV3(feed).decimals();
				return Math.mulDiv(uint256(answer), 1e18, 10 ** feedDec);
			}
			// else fall through to Mento
		}

		// --- Mento fallback ---
		address rateFeedId = mentoRateFeedOf[token];
		if (rateFeedId != address(0) && sortedOracles != address(0)) {
			ISortedOracles so = ISortedOracles(sortedOracles);
			if (so.numRates(rateFeedId) > 0) {
				uint256 ts = so.medianTimestamp(rateFeedId);
				if (ts != 0 && block.timestamp - ts <= MENTO_MAX_STALENESS) {
					(uint256 numerator, uint256 denominator) = so.medianRate(
						rateFeedId
					);
					if (denominator != 0 && numerator != 0) {
						// MENTO CONVENTION (verified on Celo mainnet fork, see
						// ForkCeloTest.test_fork_probeRealOracleSources):
						//   medianRate(rateFeedId) returns (numerator, denominator)
						//   where numerator/denominator is the price of ONE CELO
						//   denominated in the rate-feed's quote (stable) token,
						//   scaled by the "fixidity" denominator = 1e24. Observed:
						//   rateFeedId = cUSD address -> num/den = 0.0729... which
						//   equals CELO/USD (cUSD is pegged to USD). The denominator
						//   is READ from the return (NOT hardcoded), and the value is
						//   the numeraire-price of CELO, i.e. the CORRECT USD price to
						//   use as a fallback for a token that trades against cUSD
						//   (map that token -> the cUSD rate feed id). It is NOT the
						//   stable token's own USD price, so do not map cUSD->cUSD and
						//   expect $1. The non-inverted num/den form below produced the
						//   right price on-chain, so no flip is needed.
						return Math.mulDiv(numerator, 1e18, denominator);
					}
				}
			}
		}

		revert NO_PRICE_SOURCE();
	}

	/// @dev Expected `tokenOut` for `amountIn` `tokenIn` from a Uniswap v3 TWAP
	///      over `secondsAgo`. Ports the minimal OracleLibrary math.
	function _twapQuote(
		address pool,
		uint32 secondsAgo,
		address tokenIn,
		address tokenOut,
		uint256 amountIn
	) internal view returns (uint256) {
		uint32[] memory secondsAgos = new uint32[](2);
		secondsAgos[0] = secondsAgo;
		secondsAgos[1] = 0;

		(int56[] memory tickCumulatives, ) = IUniswapV3PoolMinimal(pool).observe(
			secondsAgos
		);

		int56 delta = tickCumulatives[1] - tickCumulatives[0];
		int24 meanTick = int24(delta / int56(uint56(secondsAgo)));
		// Round toward negative infinity, matching OracleLibrary.consult.
		if (delta < 0 && (delta % int56(uint56(secondsAgo)) != 0)) {
			meanTick--;
		}

		return _getQuoteAtTick(meanTick, amountIn, tokenIn, tokenOut);
	}

	/// @dev Port of Uniswap v3 OracleLibrary.getQuoteAtTick.
	function _getQuoteAtTick(
		int24 tick,
		uint256 baseAmount,
		address baseToken,
		address quoteToken
	) internal pure returns (uint256 quoteAmount) {
		uint160 sqrtRatioX96 = _getSqrtRatioAtTick(tick);

		if (sqrtRatioX96 <= type(uint128).max) {
			uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;
			quoteAmount = baseToken < quoteToken
				? Math.mulDiv(ratioX192, baseAmount, 1 << 192)
				: Math.mulDiv(1 << 192, baseAmount, ratioX192);
		} else {
			uint256 ratioX128 = Math.mulDiv(
				sqrtRatioX96,
				sqrtRatioX96,
				1 << 64
			);
			quoteAmount = baseToken < quoteToken
				? Math.mulDiv(ratioX128, baseAmount, 1 << 128)
				: Math.mulDiv(1 << 128, baseAmount, ratioX128);
		}
	}

	/// @dev Port of Uniswap v3 TickMath.getSqrtRatioAtTick. The intermediate
	///      multiplications intentionally overflow, so the whole body is unchecked.
	function _getSqrtRatioAtTick(
		int24 tick
	) internal pure returns (uint160 sqrtPriceX96) {
		unchecked {
			uint256 absTick = tick < 0
				? uint256(-int256(tick))
				: uint256(int256(tick));
			require(absTick <= 887272, "T");

			uint256 ratio = absTick & 0x1 != 0
				? 0xfffcb933bd6fad37aa2d162d1a594001
				: 0x100000000000000000000000000000000;
			if (absTick & 0x2 != 0)
				ratio = (ratio * 0xfff97272373d413259a46990580e213a) >> 128;
			if (absTick & 0x4 != 0)
				ratio = (ratio * 0xfff2e50f5f656932ef12357cf3c7fdcc) >> 128;
			if (absTick & 0x8 != 0)
				ratio = (ratio * 0xffe5caca7e10e4e61c3624eaa0941cd0) >> 128;
			if (absTick & 0x10 != 0)
				ratio = (ratio * 0xffcb9843d60f6159c9db58835c926644) >> 128;
			if (absTick & 0x20 != 0)
				ratio = (ratio * 0xff973b41fa98c081472e6896dfb254c0) >> 128;
			if (absTick & 0x40 != 0)
				ratio = (ratio * 0xff2ea16466c96a3843ec78b326b52861) >> 128;
			if (absTick & 0x80 != 0)
				ratio = (ratio * 0xfe5dee046a99a2a811c461f1969c3053) >> 128;
			if (absTick & 0x100 != 0)
				ratio = (ratio * 0xfcbe86c7900a88aedcffc83b479aa3a4) >> 128;
			if (absTick & 0x200 != 0)
				ratio = (ratio * 0xf987a7253ac413176f2b074cf7815e54) >> 128;
			if (absTick & 0x400 != 0)
				ratio = (ratio * 0xf3392b0822b70005940c7a398e4b70f3) >> 128;
			if (absTick & 0x800 != 0)
				ratio = (ratio * 0xe7159475a2c29b7443b29c7fa6e889d9) >> 128;
			if (absTick & 0x1000 != 0)
				ratio = (ratio * 0xd097f3bdfd2022b8845ad8f792aa5825) >> 128;
			if (absTick & 0x2000 != 0)
				ratio = (ratio * 0xa9f746462d870fdf8a65dc1f90e061e5) >> 128;
			if (absTick & 0x4000 != 0)
				ratio = (ratio * 0x70d869a156d2a1b890bb3df62baf32f7) >> 128;
			if (absTick & 0x8000 != 0)
				ratio = (ratio * 0x31be135f97d08fd981231505542fcfa6) >> 128;
			if (absTick & 0x10000 != 0)
				ratio = (ratio * 0x9aa508b5b7a84e1c677de54f3e99bc9) >> 128;
			if (absTick & 0x20000 != 0)
				ratio = (ratio * 0x5d6af8dedb81196699c329225ee604) >> 128;
			if (absTick & 0x40000 != 0)
				ratio = (ratio * 0x2216e584f5fa1ea926041bedfe98) >> 128;
			if (absTick & 0x80000 != 0)
				ratio = (ratio * 0x48a170391f7dc42444e8fa2) >> 128;

			if (tick > 0) ratio = type(uint256).max / ratio;

			// Round up to the next representable sqrtPriceX96.
			sqrtPriceX96 = uint160(
				(ratio >> 32) + (ratio % (1 << 32) == 0 ? 0 : 1)
			);
		}
	}
}
