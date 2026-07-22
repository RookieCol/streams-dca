// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Base} from "./Base.t.sol";
import {Errors} from "../src/core/libraries/Errors.sol";
import {Types} from "../src/core/libraries/Types.sol";

contract ExecuteSwapTest is Base {
	address internal sa;

	uint256 internal constant SUPER_IN = 100e18; // downgrades to 100 USDC
	uint256 internal constant SWAP_IN = 100e6; // USDC amountIn per swap
	uint256 internal constant OUT_AMOUNT = 50e18; // weth delivered by router
	uint24 internal constant FEE = 3000;

	function setUp() public {
		_deployProtocol();

		// Whitelist swap tokens (target whitelist is no longer consulted).
		vm.startPrank(deployer);
		config.setSupportedSwapToken(address(usdc), true);
		config.setSupportedSwapToken(address(weth), true);
		vm.stopPrank();

		// Onboard the user to get a fully configured SA.
		usdc.mint(user, USDC_AMOUNT);
		vm.startPrank(user);
		usdc.approve(address(vaults), USDC_AMOUNT);
		sa = vaults.onboard(address(usdcx), USDC_AMOUNT, RATE, _defaultRules());
		vm.stopPrank();

		// Back the super token with underlying so downgrade pays out, and fund the
		// SA with super tokens to downgrade, plus the router with tokenOut.
		usdc.mint(address(usdcx), 1_000e6);
		usdcx.mint(sa, SUPER_IN);
		weth.mint(address(router), 1_000e18);
	}

	function _params(
		address tokenIn,
		address tokenOut,
		uint256 amountIn,
		uint256 minOut
	) internal pure returns (Types.SwapParams memory) {
		return
			Types.SwapParams({
				superTokenIn: address(0),
				superAmountIn: 0,
				tokenIn: tokenIn,
				tokenOut: tokenOut,
				fee: FEE,
				amountIn: amountIn,
				minAmountOut: minOut
			});
	}

	function _goodParams() internal view returns (Types.SwapParams memory p) {
		p = _params(address(usdc), address(weth), SWAP_IN, OUT_AMOUNT);
		// Downgrade the SA's super tokens to underlying before swapping.
		p.superTokenIn = address(usdcx);
		p.superAmountIn = SUPER_IN;
	}

	function test_executeSwap_happyPath() public {
		router.configure(address(usdc), address(weth), OUT_AMOUNT, false);

		vm.prank(bot);
		uint256 amountOut = vaults.executeSwap(sa, _goodParams());

		assertEq(amountOut, OUT_AMOUNT, "amountOut");
		// Output forwarded to the user's settlement address.
		assertEq(weth.balanceOf(settlement), OUT_AMOUNT, "settlement received out");
		assertEq(weth.balanceOf(sa), 0, "nothing stuck in SA");
		// Forced recipient: the router was told to deliver to the SA itself.
		assertEq(router.lastRecipient(), sa, "router recipient forced to SA");
		// Exact-input approval fully revoked after the swap.
		assertEq(usdc.allowance(sa, address(router)), 0, "router allowance revoked");
	}

	/// Forced-recipient invariant: regardless of anything the bot supplies, the SA
	/// always passes recipient == address(smartAccount) to the router, and the
	/// output lands in the SA before being forwarded to settlement. There is no
	/// field in SwapParams that lets the bot name a recipient.
	function test_executeSwap_forcesRecipientToSmartAccount() public {
		router.configure(address(usdc), address(weth), OUT_AMOUNT, false);

		vm.prank(bot);
		vaults.executeSwap(sa, _goodParams());

		assertEq(
			router.lastRecipient(),
			sa,
			"recipient is always the smart account"
		);
		assertEq(weth.balanceOf(settlement), OUT_AMOUNT, "settled to user");
	}

	function test_executeSwap_revertNotBot() public {
		router.configure(address(usdc), address(weth), OUT_AMOUNT, false);
		vm.prank(stranger);
		vm.expectRevert(Errors.NOT_BOT.selector);
		vaults.executeSwap(sa, _goodParams());
	}

	function test_executeSwap_revertUnknownAccount() public {
		vm.prank(bot);
		vm.expectRevert(Errors.SMART_ACCOUNT_NOT_FOUND.selector);
		vaults.executeSwap(address(0xdead), _goodParams());
	}

	function test_executeSwap_revertUnsupportedSwapToken() public {
		// tokenIn not a supported swap token.
		Types.SwapParams memory p = _params(
			address(0xcafe),
			address(weth),
			SWAP_IN,
			OUT_AMOUNT
		);
		vm.prank(bot);
		vm.expectRevert(Errors.INVALID_SWAP_TOKEN.selector);
		vaults.executeSwap(sa, p);
	}

	function test_executeSwap_revertSameToken() public {
		// E-06: tokenIn == tokenOut rejected (both supported).
		Types.SwapParams memory p = _params(
			address(usdc),
			address(usdc),
			SWAP_IN,
			OUT_AMOUNT
		);
		vm.prank(bot);
		vm.expectRevert(Errors.INVALID_SWAP_TOKEN.selector);
		vaults.executeSwap(sa, p);
	}

	function test_executeSwap_revertCooldown() public {
		router.configure(address(usdc), address(weth), OUT_AMOUNT, false);

		// First swap succeeds and stamps the last-swap block.
		vm.prank(bot);
		vaults.executeSwap(sa, _goodParams());

		// Second swap in the same block hits the E-05 cooldown.
		vm.prank(bot);
		vm.expectRevert(Errors.SWAP_COOLDOWN_ACTIVE.selector);
		vaults.executeSwap(sa, _goodParams());
	}

	function test_executeSwap_revertSlippage() public {
		router.configure(address(usdc), address(weth), OUT_AMOUNT, false);
		// Demand more out than the router delivers -> INSUFFICIENT_OUTPUT.
		Types.SwapParams memory p = _goodParams();
		p.minAmountOut = OUT_AMOUNT + 1;
		vm.prank(bot);
		vm.expectRevert(Errors.INSUFFICIENT_OUTPUT.selector);
		vaults.executeSwap(sa, p);
	}

	/// A zero output floor is rejected: the realized-delta slippage check must be
	/// bound to a non-zero minimum so the swap output has to actually land in the
	/// SA.
	function test_executeSwap_revertZeroMinOut() public {
		router.configure(address(usdc), address(weth), OUT_AMOUNT, false);
		Types.SwapParams memory p = _goodParams();
		p.minAmountOut = 0;
		vm.prank(bot);
		vm.expectRevert(Errors.INVALID_AMOUNT.selector);
		vaults.executeSwap(sa, p);
	}

	/// A zero input is rejected.
	function test_executeSwap_revertZeroAmountIn() public {
		router.configure(address(usdc), address(weth), OUT_AMOUNT, false);
		Types.SwapParams memory p = _goodParams();
		p.amountIn = 0;
		vm.prank(bot);
		vm.expectRevert(Errors.INVALID_AMOUNT.selector);
		vaults.executeSwap(sa, p);
	}

	/// amountIn exceeding the held balance is rejected.
	function test_executeSwap_revertAmountInExceedsBalance() public {
		router.configure(address(usdc), address(weth), OUT_AMOUNT, false);
		Types.SwapParams memory p = _goodParams();
		p.amountIn = SWAP_IN + 1; // more than the 100 USDC available after downgrade
		vm.prank(bot);
		vm.expectRevert(Errors.TRADE_BELOW_MIN.selector);
		vaults.executeSwap(sa, p);
	}

	/// E-05 release: after a swap stamps the block, advancing one block (default
	/// cooldown = 1) lets the next swap through.
	function test_executeSwap_cooldownReleasesNextBlock() public {
		router.configure(address(usdc), address(weth), OUT_AMOUNT, false);

		vm.prank(bot);
		vaults.executeSwap(sa, _goodParams());

		// Re-fund the SA so the second swap has input to trade.
		usdcx.mint(sa, SUPER_IN);

		vm.roll(block.number + 1);
		vm.prank(bot);
		uint256 amountOut = vaults.executeSwap(sa, _goodParams());
		assertEq(amountOut, OUT_AMOUNT, "second swap succeeds after cooldown release");
	}

	/// E-05 boundary with a multi-block cooldown: block+1 still reverts, block+2
	/// (the exact boundary) succeeds.
	function test_executeSwap_cooldownBoundaryMultiBlock() public {
		vm.prank(deployer);
		vaults.setSwapCooldown(2);

		router.configure(address(usdc), address(weth), OUT_AMOUNT, false);

		// Advance past the cooldown window so the first-ever swap is eligible.
		vm.roll(block.number + 2);

		vm.prank(bot);
		vaults.executeSwap(sa, _goodParams());
		uint256 firstBlock = block.number;

		usdcx.mint(sa, SUPER_IN);

		// One block later is still inside the 2-block cooldown.
		vm.roll(firstBlock + 1);
		vm.prank(bot);
		vm.expectRevert(Errors.SWAP_COOLDOWN_ACTIVE.selector);
		vaults.executeSwap(sa, _goodParams());

		// The boundary block releases it.
		vm.roll(firstBlock + 2);
		vm.prank(bot);
		uint256 amountOut = vaults.executeSwap(sa, _goodParams());
		assertEq(amountOut, OUT_AMOUNT, "swap succeeds at cooldown boundary block");
	}

	/// Regression for the disabled-cooldown underflow: with cooldown = 0 the first
	/// swap of a never-traded account (_lastSwapBlock == 0) must NOT underflow, and
	/// consecutive same-block swaps are unthrottled.
	function test_executeSwap_cooldownDisabledNoUnderflow() public {
		vm.prank(deployer);
		vaults.setSwapCooldown(0);

		router.configure(address(usdc), address(weth), OUT_AMOUNT, false);

		vm.prank(bot);
		uint256 amountOut = vaults.executeSwap(sa, _goodParams());
		assertEq(amountOut, OUT_AMOUNT, "first swap succeeds with cooldown disabled");

		// Same-block second swap is allowed when the cooldown is disabled.
		usdcx.mint(sa, SUPER_IN);
		vm.prank(bot);
		vaults.executeSwap(sa, _goodParams());
	}

	/// The no-downgrade branch: superAmountIn == 0 with the SA pre-funded in the
	/// underlying directly. The swap proceeds without any SuperToken downgrade.
	function test_executeSwap_noDowngrade() public {
		router.configure(address(usdc), address(weth), OUT_AMOUNT, false);

		// Fund the SA with underlying directly (nothing to downgrade).
		usdc.mint(sa, 100e6);

		Types.SwapParams memory p = _params(
			address(usdc),
			address(weth),
			SWAP_IN,
			OUT_AMOUNT
		);

		vm.prank(bot);
		uint256 amountOut = vaults.executeSwap(sa, p);
		assertEq(amountOut, OUT_AMOUNT, "swap proceeds without downgrade");
		assertEq(weth.balanceOf(settlement), OUT_AMOUNT, "output settled to user");
	}
}
