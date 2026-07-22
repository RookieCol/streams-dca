// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Base} from "./Base.t.sol";
import {Errors} from "../src/core/libraries/Errors.sol";
import {Types} from "../src/core/libraries/Types.sol";
import {ISmartAccountDCA} from "../src/strategies/dca/interfaces/ISmartAccountDCA.sol";

contract SmartAccountDCATest is Base {
	ISmartAccountDCA internal sa;

	function setUp() public {
		_deployProtocol();
		vm.prank(user);
		sa = ISmartAccountDCA(vaults.createSmartAccount());
	}

	function test_ownerAndOperatorSet() public view {
		assertEq(sa.owner(), user);
		assertEq(sa.operator(), address(vaults));
	}

	function test_setRules_onlyOwner() public {
		vm.prank(stranger);
		vm.expectRevert(Errors.NOT_OWNER.selector);
		sa.setRules(_defaultRules());
	}

	function test_setRules_happy() public {
		vm.prank(user);
		sa.setRules(_defaultRules());
		(uint16 slip, uint256 minTrade, address settleAddr) = sa.rules();
		assertEq(slip, 100);
		assertEq(minTrade, 1e6);
		assertEq(settleAddr, settlement);
		assertTrue(sa.isTargetToken(address(weth)));
	}

	function test_setRules_revertZeroSettlement() public {
		Types.UserRules memory r = _defaultRules();
		r.settlementAddress = address(0);
		vm.prank(user);
		vm.expectRevert(Errors.INVALID_RULES.selector);
		sa.setRules(r);
	}

	function test_setRules_revertEmptyTargets() public {
		Types.UserRules memory r = _defaultRules();
		r.targetTokens = new address[](0);
		vm.prank(user);
		vm.expectRevert(Errors.INVALID_RULES.selector);
		sa.setRules(r);
	}

	function test_setRules_revertSlippageTooHigh() public {
		Types.UserRules memory r = _defaultRules();
		r.maxSlippageBps = 5_001; // > MAX_SLIPPAGE_BPS (5000)
		vm.prank(user);
		vm.expectRevert(Errors.INVALID_RULES.selector);
		sa.setRules(r);
	}

	function test_executeSwap_onlyOperator() public {
		Types.SwapParams memory p;
		p.tokenIn = address(usdc);
		p.tokenOut = address(weth);
		p.fee = 3000;
		p.amountIn = 1e6;
		vm.prank(stranger);
		vm.expectRevert(Errors.NOT_OPERATOR.selector);
		sa.executeSwap(p);
	}

	function test_withdraw_onlyOwner() public {
		usdc.mint(address(sa), 100e6);
		vm.prank(stranger);
		vm.expectRevert(Errors.NOT_OWNER.selector);
		sa.withdraw(address(usdc), 100e6, user);
	}

	function test_withdraw_happy() public {
		usdc.mint(address(sa), 100e6);
		vm.prank(user);
		sa.withdraw(address(usdc), 40e6, user);
		assertEq(usdc.balanceOf(user), 40e6);
		assertEq(usdc.balanceOf(address(sa)), 60e6);
	}

	function test_withdraw_revertZeroTo() public {
		usdc.mint(address(sa), 100e6);
		vm.prank(user);
		vm.expectRevert(Errors.INVALID_ADDRESS.selector);
		sa.withdraw(address(usdc), 40e6, address(0));
	}

	function test_withdrawAll_happy() public {
		usdc.mint(address(sa), 123e6);
		vm.prank(user);
		sa.withdrawAll(address(usdc), user);
		assertEq(usdc.balanceOf(user), 123e6);
		assertEq(usdc.balanceOf(address(sa)), 0);
	}

	function test_withdrawAll_onlyOwner() public {
		usdc.mint(address(sa), 123e6);
		vm.prank(stranger);
		vm.expectRevert(Errors.NOT_OWNER.selector);
		sa.withdrawAll(address(usdc), stranger);
	}
}
