// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Base} from "./Base.t.sol";
import {Errors} from "../src/core/libraries/Errors.sol";

/// @notice Factory (create/redeploy) + auto-close guardian coverage.
contract LifecycleTest is Base {
	function setUp() public {
		_deployProtocol();
	}

	// ---- factory ----

	function test_createSmartAccount_duplicateReverts() public {
		vm.prank(user);
		vaults.createSmartAccount();
		vm.prank(user);
		vm.expectRevert(Errors.SMART_ACCOUNT_ALREADY_EXISTS.selector);
		vaults.createSmartAccount();
	}

	function test_redeploySmartAccount() public {
		vm.prank(user);
		address first = vaults.createSmartAccount();

		vm.prank(user);
		address second = vaults.redeploySmartAccount();

		assertTrue(second != first, "new clone");
		assertEq(vaults.smartAccountOf(user), second, "mapping updated");
		assertEq(vaults.userOf(second), user, "reverse mapping");
		assertEq(vaults.userOf(first), address(0), "old detached");
	}

	function test_redeploySmartAccount_revertNoAccount() public {
		vm.prank(user);
		vm.expectRevert(Errors.SMART_ACCOUNT_NOT_FOUND.selector);
		vaults.redeploySmartAccount();
	}

	// ---- closeStreamIfLow ----

	function _onboard() internal returns (address sa) {
		usdc.mint(user, USDC_AMOUNT);
		vm.startPrank(user);
		usdc.approve(address(vaults), USDC_AMOUNT);
		sa = vaults.onboard(address(usdcx), USDC_AMOUNT, RATE, _defaultRules());
		vm.stopPrank();
	}

	function test_closeStreamIfLow_onlyBot() public {
		address sa = _onboard();
		vm.prank(stranger);
		vm.expectRevert(Errors.NOT_BOT.selector);
		vaults.closeStreamIfLow(sa, address(usdcx));
	}

	function test_closeStreamIfLow_revertNotActive() public {
		// SA with no stream open.
		vm.prank(user);
		address sa = vaults.createSmartAccount();
		vm.prank(bot);
		vm.expectRevert(Errors.STREAM_NOT_ACTIVE.selector);
		vaults.closeStreamIfLow(sa, address(usdcx));
	}

	function test_closeStreamIfLow_revertNotLow() public {
		address sa = _onboard();
		// Plenty of spendable balance above the buffer trigger.
		usdcx.setRealtimeBalance(user, int256(1_000e18), 1e18);
		vm.prank(bot);
		vm.expectRevert(Errors.STREAM_NOT_LOW.selector);
		vaults.closeStreamIfLow(sa, address(usdcx));
	}

	function test_closeStreamIfLow_closesWhenLow() public {
		address sa = _onboard();
		assertEq(forwarder.getFlowrate(address(usdcx), user, sa), RATE, "open");

		// availableBalance (0) <= trigger (10% of 1e18 deposit = 1e17).
		usdcx.setRealtimeBalance(user, int256(0), 1e18);

		vm.prank(bot);
		bool closed = vaults.closeStreamIfLow(sa, address(usdcx));

		assertTrue(closed, "closed");
		assertEq(forwarder.getFlowrate(address(usdcx), user, sa), int96(0), "stream closed");
	}
}
