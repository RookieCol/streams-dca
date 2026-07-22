// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Base} from "./Base.t.sol";
import {Errors} from "../src/core/libraries/Errors.sol";
import {Types} from "../src/core/libraries/Types.sol";
import {ISmartAccountDCA} from "../src/strategies/dca/interfaces/ISmartAccountDCA.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract OnboardTest is Base {
	function setUp() public {
		_deployProtocol();
		// Fund the user with underlying and back the super token so downgrades work.
		usdc.mint(user, USDC_AMOUNT);
	}

	/// Happy path: approve (tx1) + grantPermissions is implicit for the mock
	/// forwarder, then onboard deploys the SA, wraps underlying, sets rules, and
	/// opens the stream.
	function test_onboard_happyPath() public {
		vm.prank(user);
		usdc.approve(address(vaults), USDC_AMOUNT);

		vm.prank(user);
		address sa = vaults.onboard(
			address(usdcx),
			USDC_AMOUNT,
			RATE,
			_defaultRules()
		);

		// SA deployed and wired.
		assertTrue(sa != address(0), "sa deployed");
		assertEq(vaults.smartAccountOf(user), sa, "smartAccountOf");
		assertEq(vaults.userOf(sa), user, "userOf");

		// Underlying pulled + wrapped: user received 18-dec super tokens.
		assertEq(usdc.balanceOf(user), 0, "underlying pulled");
		assertEq(usdcx.balanceOf(user), USDC_AMOUNT * 1e12, "super minted");

		// Rules set on the SA.
		(uint16 slippage, uint256 minTrade, address settleAddr) = ISmartAccountDCA(sa)
			.rules();
		assertEq(slippage, 100);
		assertEq(minTrade, 1e6);
		assertEq(settleAddr, settlement);
		assertTrue(ISmartAccountDCA(sa).isTargetToken(address(weth)));

		// Stream opened: forwarder reports the flowrate.
		assertEq(forwarder.getFlowrate(address(usdcx), user, sa), RATE, "flowrate");
	}

	/// Core migration behavior: without a prior ERC20 approve, onboard reverts on
	/// the safeTransferFrom pull (there is no permit fallback anymore).
	function test_onboard_revertsWithoutApprove() public {
		// Pin the failure to the safeTransferFrom allowance check: without a prior
		// approve, the ERC20 pull reverts with ERC20InsufficientAllowance(spender=
		// vaults, allowance=0, needed=USDC_AMOUNT). Proves the missing-permit-fallback
		// behavior, not an unrelated early revert.
		vm.prank(user);
		vm.expectRevert(
			abi.encodeWithSelector(
				IERC20Errors.ERC20InsufficientAllowance.selector,
				address(vaults),
				0,
				USDC_AMOUNT
			)
		);
		vaults.onboard(address(usdcx), USDC_AMOUNT, RATE, _defaultRules());
	}

	function test_onboard_revertZeroSuperToken() public {
		vm.prank(user);
		vm.expectRevert(Errors.INVALID_ADDRESS.selector);
		vaults.onboard(address(0), USDC_AMOUNT, RATE, _defaultRules());
	}

	function test_onboard_revertZeroAmount() public {
		vm.prank(user);
		vm.expectRevert(Errors.INVALID_AMOUNT.selector);
		vaults.onboard(address(usdcx), 0, RATE, _defaultRules());
	}

	function test_onboard_revertZeroRate() public {
		vm.prank(user);
		vm.expectRevert(Errors.INVALID_RATE.selector);
		vaults.onboard(address(usdcx), USDC_AMOUNT, int96(0), _defaultRules());
	}

	function test_onboard_revertNegativeRate() public {
		vm.prank(user);
		vm.expectRevert(Errors.INVALID_RATE.selector);
		vaults.onboard(address(usdcx), USDC_AMOUNT, int96(-1), _defaultRules());
	}

	function test_onboard_revertRateTooLow() public {
		// rate * window < minTradeAmount => RATE_TOO_LOW.
		Types.UserRules memory r = _defaultRules();
		r.minTradeAmount = 1e30; // impossibly high for a rate of 1 over 1 day
		vm.prank(user);
		vm.expectRevert(Errors.RATE_TOO_LOW.selector);
		vaults.onboard(address(usdcx), USDC_AMOUNT, int96(1), r);
	}

	function test_onboard_revertUnsupportedUnderlying() public {
		// A super token that reports address(0) as underlying is rejected.
		MockSuperTokenNoUnderlying nativeSuper = new MockSuperTokenNoUnderlying();
		vm.prank(user);
		vm.expectRevert(Errors.UNSUPPORTED_UNDERLYING.selector);
		vaults.onboard(address(nativeSuper), USDC_AMOUNT, RATE, _defaultRules());
	}
}

/// @dev Minimal super token whose underlying is the zero address (native super token).
contract MockSuperTokenNoUnderlying {
	function getUnderlyingToken() external pure returns (address) {
		return address(0);
	}

	function getUnderlyingDecimals() external pure returns (uint8) {
		return 18;
	}
}
