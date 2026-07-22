// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Base} from "./Base.t.sol";
import {Errors} from "../src/core/libraries/Errors.sol";
import {IStreamVaults} from "../src/core/interfaces/IStreamVaults/IStreamVaults.sol";

/// @notice Coverage for the standalone `setStream` entrypoint and the owner-only
///         configuration setters (`setSwapCooldown`, `setStreamCloseThreshold`),
///         including their auth and bound guards.
contract OwnerConfigTest is Base {
	int96 internal constant NEW_RATE = int96(2e12);

	function setUp() public {
		_deployProtocol();
	}

	function _onboard() internal returns (address sa) {
		usdc.mint(user, USDC_AMOUNT);
		vm.startPrank(user);
		usdc.approve(address(vaults), USDC_AMOUNT);
		sa = vaults.onboard(address(usdcx), USDC_AMOUNT, RATE, _defaultRules());
		vm.stopPrank();
	}

	// -------------------------------------------------------------------------
	// setStream
	// -------------------------------------------------------------------------

	function test_setStream_happy() public {
		address sa = _onboard();
		assertEq(forwarder.getFlowrate(address(usdcx), user, sa), RATE, "initial rate");

		vm.prank(user);
		vaults.setStream(sa, address(usdcx), NEW_RATE);

		assertEq(
			forwarder.getFlowrate(address(usdcx), user, sa),
			NEW_RATE,
			"rate updated by owner"
		);
	}

	function test_setStream_revertNotOwner() public {
		address sa = _onboard();
		vm.prank(stranger);
		vm.expectRevert(Errors.NOT_SMART_ACCOUNT_OWNER.selector);
		vaults.setStream(sa, address(usdcx), NEW_RATE);
	}

	function test_setStream_revertUnknownAccount() public {
		vm.prank(user);
		vm.expectRevert(Errors.SMART_ACCOUNT_NOT_FOUND.selector);
		vaults.setStream(address(0xdead), address(usdcx), NEW_RATE);
	}

	function test_setStream_revertNegativeRate() public {
		address sa = _onboard();
		vm.prank(user);
		vm.expectRevert(Errors.INVALID_RATE.selector);
		vaults.setStream(sa, address(usdcx), int96(-1));
	}

	// -------------------------------------------------------------------------
	// setSwapCooldown
	// -------------------------------------------------------------------------

	function test_setSwapCooldown_happy() public {
		vm.expectEmit(false, false, false, true, address(vaults));
		emit IStreamVaults.SwapCooldownUpdated(5);

		vm.prank(deployer);
		vaults.setSwapCooldown(5);

		assertEq(vaults.swapCooldownBlocks(), 5, "cooldown updated");
	}

	function test_setSwapCooldown_onlyOwner() public {
		vm.prank(stranger);
		vm.expectRevert(
			abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", stranger)
		);
		vaults.setSwapCooldown(5);
	}

	// -------------------------------------------------------------------------
	// setStreamCloseThreshold
	// -------------------------------------------------------------------------

	function test_setStreamCloseThreshold_happy() public {
		vm.expectEmit(false, false, false, true, address(vaults));
		emit IStreamVaults.StreamCloseThresholdUpdated(2_500);

		vm.prank(deployer);
		vaults.setStreamCloseThreshold(2_500);

		assertEq(vaults.streamCloseThresholdBps(), 2_500, "threshold updated");
	}

	function test_setStreamCloseThreshold_onlyOwner() public {
		vm.prank(stranger);
		vm.expectRevert(
			abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", stranger)
		);
		vaults.setStreamCloseThreshold(2_500);
	}

	function test_setStreamCloseThreshold_revertAboveMax() public {
		vm.prank(deployer);
		vm.expectRevert(Errors.INVALID_THRESHOLD.selector);
		vaults.setStreamCloseThreshold(10_001);
	}
}
