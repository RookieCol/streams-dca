// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// third party
/// openzeppelin
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// local
/// interfaces
import {IStreamVaults} from "./interfaces/IStreamVaults/IStreamVaults.sol";
import {IStreamVaultsConfig} from "./interfaces/IStreamVaults/IStreamVaultsConfig.sol";
import {ICFAv1Forwarder} from "./interfaces/external/ICFAv1Forwarder.sol";
import {ISuperToken} from "./interfaces/external/ISuperToken.sol";
import {ISmartAccountDCA} from "../strategies/dca/interfaces/ISmartAccountDCA.sol";
/// libraries
import {Errors} from "./libraries/Errors.sol";
import {Types} from "./libraries/Types.sol";

/// @title StreamVaults
/// @notice Central gateway of the protocol. Three responsibilities:
///         1. Factory: deploys EIP-1167 clones of `SmartAccountDCA` (one per user).
///         2. Stream gateway: routes Superfluid flow create/update/delete via
///            CFAv1Forwarder using the user's pre-granted ACL permissions.
///         3. Swap orchestrator: validates the swap-token whitelist and forwards
///            swap requests from the bot to the user's smart account, which routes
///            them through the fixed config-set SwapRouter02 (forced recipient).
contract StreamVaults is
	IStreamVaults,
	Initializable,
	OwnableUpgradeable,
	UUPSUpgradeable,
	Errors
{
	using Clones for address;
	using SafeERC20 for IERC20;

	/// =====================
	/// ====== Storage ======
	/// =====================

	address private _config;
	mapping(address => address) private _smartAccountOf;
	mapping(address => address) private _userOf;

	/// @notice Per-SA last swap block for rate limiting.
	mapping(address => uint256) private _lastSwapBlock;

	/// @notice Cooldown in blocks between consecutive swaps per SA. Default: 1 block.
	uint256 private _swapCooldownBlocks;

	/// @notice Auto-close trigger, in bps of the Superfluid buffer. `closeStreamIfLow`
	///         fires when the sender's spendable balance is at or below this fraction
	///         of the locked deposit. Default: 1000 (10%).
	uint256 private _streamCloseThresholdBps;

	/// =====================
	/// ======== Init =======
	/// =====================

	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor() {
		_disableInitializers();
	}

	function initialize(
		address owner_,
		address config_
	) external initializer {
		if (isZeroAddress(owner_) || isZeroAddress(config_)) {
			revert INVALID_ADDRESS();
		}
		__Ownable_init(owner_);
		_config = config_;
		_swapCooldownBlocks = 1;
		_streamCloseThresholdBps = 1_000; // 10% of the buffer
	}

	/// =====================
	/// ======= User ========
	/// =====================

	function createSmartAccount() external returns (address smartAccount) {
		smartAccount = _deploySmartAccount(msg.sender);
		ISmartAccountDCA(smartAccount).initialize(msg.sender, address(this));
	}

	/// @notice Replaces the caller's smart account with a fresh clone on the
	///         CURRENT implementation. Use after an implementation upgrade: the
	///         old EIP-1167 clone is immutable, so this detaches it and deploys a
	///         new one pointing at `config.smartAccountImplementation()`.
	/// @dev The caller MUST have closed any stream and withdrawn all funds from
	///      the old account first — the old clone is abandoned (not destroyed),
	///      and the new account starts with no rules. Reverts with
	///      SMART_ACCOUNT_NOT_FOUND if the caller has no account yet.
	function redeploySmartAccount()
		external
		returns (address smartAccount)
	{
		address old = _smartAccountOf[msg.sender];
		if (isZeroAddress(old)) revert SMART_ACCOUNT_NOT_FOUND();

		// Detach the old clone so `_deploySmartAccount` can mint a new one.
		_smartAccountOf[msg.sender] = address(0);
		_userOf[old] = address(0);

		smartAccount = _deploySmartAccount(msg.sender);
		ISmartAccountDCA(smartAccount).initialize(msg.sender, address(this));

		emit SmartAccountRedeployed(msg.sender, old, smartAccount);
	}

	function setStream(
		address smartAccount,
		address superToken,
		int96 rate
	) external {
		address user = _userOf[smartAccount];
		if (isZeroAddress(user)) revert SMART_ACCOUNT_NOT_FOUND();
		if (msg.sender != user) revert NOT_SMART_ACCOUNT_OWNER();
		// E-01 / E-04: reject negative rates at the gateway level.
		if (rate < 0) revert INVALID_RATE();
		_setStream(user, smartAccount, superToken, rate);
	}

	/// @notice One-shot setup entrypoint: pulls the pre-approved underlying token,
	///         wraps it into the SuperToken for `msg.sender`, deploys +
	///         configures their SmartAccountDCA, and opens the stream into it.
	/// @dev Standard two-step onboarding, no permit involved. The expected flow is:
	///      (tx1) `msg.sender` calls `approve(underlying)` granting this contract an
	///      ERC20 allowance of at least `underlyingAmount`; (tx2) `msg.sender` calls
	///      `grantPermissions` on the CFAv1Forwarder to make this contract a flow
	///      operator for `superToken`; (tx3) `msg.sender` calls `onboard`.
	/// @param superToken       SuperToken to stream (e.g. USDCx). Its underlying
	///                         token is queried on-chain and pulled via the prior
	///                         ERC20 approval.
	/// @param underlyingAmount Amount of underlying to wrap, in the underlying's
	///                         native decimals (e.g. 6 for USDC).
	/// @param rate             Flow rate in wei/sec (SuperToken units).
	/// @param rules            Initial trading rules applied to the smart account.
	function onboard(
		address superToken,
		uint256 underlyingAmount,
		int96 rate,
		Types.UserRules calldata rules
	) external returns (address smartAccount) {
		if (isZeroAddress(superToken)) revert INVALID_ADDRESS();
		if (underlyingAmount == 0) revert INVALID_AMOUNT();
		if (rate <= 0) revert INVALID_RATE();
		// E-07: reject streams whose rate can never accumulate enough for one trade
		// within the minimum accumulation window. The window is configurable
		// via `StreamVaultsConfig.minStreamAccumulationWindow` (default 86400s).
		if (
			uint256(uint96(rate)) *
				IStreamVaultsConfig(_config).minStreamAccumulationWindow() <
			rules.minTradeAmount
		) revert RATE_TOO_LOW();

		address underlying = ISuperToken(superToken).getUnderlyingToken();
		if (isZeroAddress(underlying)) revert UNSUPPORTED_UNDERLYING();

		// 1. Pull `underlyingAmount` of the underlying token using the allowance
		//    the user granted in a prior standard ERC20 `approve()` tx.
		IERC20(underlying).safeTransferFrom(
			msg.sender,
			address(this),
			underlyingAmount
		);

		// 2. Wrap USDC -> USDCx, delivered directly to msg.sender's EOA.
		//    SuperToken amount is 18-decimal; underlying amount is native-dec.
		uint256 superAmount = underlyingAmount *
			(10 ** (18 - ISuperToken(superToken).getUnderlyingDecimals()));
		IERC20(underlying).forceApprove(superToken, underlyingAmount);
		ISuperToken(superToken).upgradeTo(msg.sender, superAmount, "");

		// 3. Deploy + initialize the SmartAccount with rules atomically.
		smartAccount = _deploySmartAccount(msg.sender);
		ISmartAccountDCA(smartAccount).initializeWithRules(
			msg.sender,
			address(this),
			rules
		);

		// 4. Open the stream from msg.sender -> SmartAccount via the forwarder
		//    (requires the user-granted CFA flow-operator permission).
		_setStream(msg.sender, smartAccount, superToken, rate);

		emit Onboarded(
			msg.sender,
			smartAccount,
			superToken,
			underlyingAmount,
			superAmount,
			rate
		);
	}

	/// =====================
	/// ======== Bot ========
	/// =====================

	function executeSwap(
		address smartAccount,
		Types.SwapParams calldata params
	) external returns (uint256 amountOut) {
		if (msg.sender != IStreamVaultsConfig(_config).bot()) revert NOT_BOT();
		amountOut = _executeSwap(smartAccount, params);
	}

	/// @notice Pre-emptively closes a user's stream when their spendable balance
	///         has fallen to within `_streamCloseThresholdBps` of the Superfluid
	///         buffer. Bot-only guardian: closing while the sender is still
	///         solvent returns the full deposit to them and avoids the
	///         liquidation penalty. The bot only stops the flow — it never moves
	///         or redirects the user's funds.
	/// @dev The deposit is released to the sender's SuperToken balance by the CFA
	///      on a clean close; this contract never custodies it.
	function closeStreamIfLow(
		address smartAccount,
		address superToken
	) external returns (bool closed) {
		if (msg.sender != IStreamVaultsConfig(_config).bot()) revert NOT_BOT();
		closed = _closeStreamIfLow(smartAccount, superToken);
	}

	/// =====================
	/// ====== Owner ========
	/// =====================

	/// @notice Sets the minimum number of blocks required between consecutive
	///         swaps for any given smart account. Owner-only.
	/// @param cooldownBlocks Number of blocks to wait. Set to 0 to disable.
	function setSwapCooldown(uint256 cooldownBlocks) external onlyOwner {
		_swapCooldownBlocks = cooldownBlocks;
		emit SwapCooldownUpdated(cooldownBlocks);
	}

	/// @notice Sets the auto-close threshold, in bps of the Superfluid buffer.
	///         `closeStreamIfLow` fires when the sender's spendable balance is at
	///         or below this fraction of the locked deposit. Owner-only. Max 10000.
	/// @param thresholdBps Threshold in bps (1000 = 10%). 0 closes only once critical.
	function setStreamCloseThreshold(uint256 thresholdBps) external onlyOwner {
		if (thresholdBps > 10_000) revert INVALID_THRESHOLD();
		_streamCloseThresholdBps = thresholdBps;
		emit StreamCloseThresholdUpdated(thresholdBps);
	}

	/// =====================
	/// ======= Views =======
	/// =====================

	function smartAccountOf(
		address user
	) external view returns (address) {
		return _smartAccountOf[user];
	}

	function userOf(
		address smartAccount
	) external view returns (address) {
		return _userOf[smartAccount];
	}

	function config() external view returns (address) {
		return _config;
	}

	function swapCooldownBlocks() external view returns (uint256) {
		return _swapCooldownBlocks;
	}

	function lastSwapBlock(address smartAccount) external view returns (uint256) {
		return _lastSwapBlock[smartAccount];
	}

	function streamCloseThresholdBps() external view returns (uint256) {
		return _streamCloseThresholdBps;
	}

	/// =====================
	/// ====== Internal =====
	/// =====================

	function _deploySmartAccount(
		address user
	) internal returns (address smartAccount) {
		if (_smartAccountOf[user] != address(0)) {
			revert SMART_ACCOUNT_ALREADY_EXISTS();
		}
		address impl = IStreamVaultsConfig(_config).smartAccountImplementation();
		if (isZeroAddress(impl)) revert SMART_ACCOUNT_IMPL_NOT_SET();

		smartAccount = impl.clone();
		_smartAccountOf[user] = smartAccount;
		_userOf[smartAccount] = user;

		emit SmartAccountCreated(user, smartAccount);
	}

	/// @dev Shared swap logic backing the bot-only `executeSwap`. Caller is
	///      responsible for authorization; this enforces every protocol guard
	///      (account exists, swap-token whitelist, E-06 same-token, E-05
	///      cooldown) before forwarding to the smart account. The swap itself is
	///      routed through the fixed config-set SwapRouter02 by the smart account,
	///      with recipient hardcoded to the account, so there is no bot-supplied
	///      target to validate here.
	function _executeSwap(
		address smartAccount,
		Types.SwapParams memory params
	) internal returns (uint256 amountOut) {
		IStreamVaultsConfig cfg = IStreamVaultsConfig(_config);
		if (isZeroAddress(_userOf[smartAccount])) {
			revert SMART_ACCOUNT_NOT_FOUND();
		}
		if (
			!cfg.isSupportedSwapToken(params.tokenIn) ||
			!cfg.isSupportedSwapToken(params.tokenOut)
		) revert INVALID_SWAP_TOKEN();
		// E-06: reject swaps where input and output token are the same.
		if (params.tokenIn == params.tokenOut) revert INVALID_SWAP_TOKEN();
		// E-05: per-SA swap cooldown to limit bot drain speed. Guard against the
		// `_swapCooldownBlocks == 0` (disabled) case explicitly: the previous
		// `+ _swapCooldownBlocks - 1` form underflowed to a revert on the first
		// swap of every account when the cooldown was disabled. This form is
		// equivalent for cooldown >= 1 and a clean no-op when disabled.
		if (
			_swapCooldownBlocks != 0 &&
			block.number < _lastSwapBlock[smartAccount] + _swapCooldownBlocks
		) {
			revert SWAP_COOLDOWN_ACTIVE();
		}
		_lastSwapBlock[smartAccount] = block.number;

		amountOut = ISmartAccountDCA(smartAccount).executeSwap(params);

		emit SwapExecuted(
			smartAccount,
			params.tokenIn,
			params.tokenOut,
			params.amountIn,
			amountOut
		);
	}

	/// @dev Shared auto-close logic backing the bot-only `closeStreamIfLow`.
	///      Caller is responsible for authorization; this only stops the flow
	///      when the sender is still solvent and near the buffer, never moving
	///      funds.
	function _closeStreamIfLow(
		address smartAccount,
		address superToken
	) internal returns (bool closed) {
		if (isZeroAddress(superToken)) revert INVALID_ADDRESS();

		address user = _userOf[smartAccount];
		if (isZeroAddress(user)) revert SMART_ACCOUNT_NOT_FOUND();

		address forwarder = IStreamVaultsConfig(_config).cfaForwarder();
		if (isZeroAddress(forwarder)) revert FORWARDER_NOT_SET();

		int96 rate = ICFAv1Forwarder(forwarder).getFlowrate(
			superToken,
			user,
			smartAccount
		);
		if (rate <= 0) revert STREAM_NOT_ACTIVE();

		(int256 availableBalance, uint256 deposit, , ) = ISuperToken(superToken)
			.realtimeBalanceOfNow(user);

		// Trigger while still solvent: the spendable headroom above the buffer
		// must have fallen to <= thresholdBps of the buffer.
		int256 trigger = int256((deposit * _streamCloseThresholdBps) / 10_000);
		if (availableBalance > trigger) revert STREAM_NOT_LOW();

		_setStream(user, smartAccount, superToken, 0);
		emit StreamAutoClosed(
			user,
			smartAccount,
			superToken,
			availableBalance,
			deposit
		);
		return true;
	}

	function _setStream(
		address user,
		address smartAccount,
		address superToken,
		int96 rate
	) internal {
		if (isZeroAddress(superToken)) revert INVALID_ADDRESS();

		address forwarder = IStreamVaultsConfig(_config).cfaForwarder();
		if (isZeroAddress(forwarder)) revert FORWARDER_NOT_SET();

		int96 prevRate = ICFAv1Forwarder(forwarder).getFlowrate(
			superToken,
			user,
			smartAccount
		);
		ICFAv1Forwarder(forwarder).setFlowrateFrom(
			superToken,
			user,
			smartAccount,
			rate
		);

		emit StreamUpdated(user, smartAccount, superToken, prevRate, rate);
	}

	/// =====================
	/// ====== Upgrade ======
	/// =====================

	function _authorizeUpgrade(
		address newImplementation
	) internal override onlyOwner {}
}
