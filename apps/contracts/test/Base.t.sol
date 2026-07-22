// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {StreamVaults} from "../src/core/StreamVaults.sol";
import {StreamVaultsConfig} from "../src/core/StreamVaultsConfig.sol";
import {SmartAccountDCA} from "../src/strategies/dca/SmartAccountDCA.sol";
import {Types} from "../src/core/libraries/Types.sol";

import {MockERC20Permit} from "./mocks/MockERC20Permit.sol";
import {MockSuperToken} from "./mocks/MockSuperToken.sol";
import {MockCFAv1Forwarder} from "./mocks/MockCFAv1Forwarder.sol";
import {MockPermit2} from "./mocks/MockPermit2.sol";
import {MockUniswapRouter, MockMintableERC20} from "./mocks/MockUniswapRouter.sol";

/// @notice Shared deployment fixture for the unit-test suite. Wires the protocol
///         up with mocks so behavior is deterministic and fork-free.
contract Base is Test {
	// Actors
	address internal deployer = makeAddr("deployer");
	address internal bot = makeAddr("bot");
	address internal user = makeAddr("user");
	address internal stranger = makeAddr("stranger");
	address internal settlement = makeAddr("settlement");

	// Protocol
	StreamVaultsConfig internal config;
	StreamVaults internal vaults;
	SmartAccountDCA internal saImpl;

	// Mocks
	MockERC20Permit internal usdc; // underlying, 6 decimals
	MockSuperToken internal usdcx; // super token, 18 decimals
	MockCFAv1Forwarder internal forwarder;
	MockPermit2 internal permit2;
	MockUniswapRouter internal router;
	MockMintableERC20 internal weth; // tokenOut, 18 decimals

	uint256 internal constant WINDOW = 86_400; // 1 day
	uint256 internal constant USDC_AMOUNT = 200e6; // 200 USDC
	int96 internal constant RATE = int96(1e12); // wei/sec

	function _deployProtocol() internal {
		vm.startPrank(deployer);

		// Mocks
		usdc = new MockERC20Permit("USD Coin", "USDC", 6);
		usdcx = new MockSuperToken("Super USDC", "USDCx", address(usdc), 6);
		forwarder = new MockCFAv1Forwarder();
		permit2 = new MockPermit2();
		router = new MockUniswapRouter();
		weth = new MockMintableERC20("Wrapped Ether", "WETH");

		// SmartAccountDCA implementation (clone target)
		saImpl = new SmartAccountDCA();

		// Config behind a UUPS proxy.
		StreamVaultsConfig cfgImpl = new StreamVaultsConfig();
		bytes memory cfgInit = abi.encodeCall(
			StreamVaultsConfig.initialize,
			(
				deployer,
				bot,
				address(saImpl),
				address(permit2),
				address(router),
				address(forwarder),
				WINDOW
			)
		);
		config = StreamVaultsConfig(
			address(new ERC1967Proxy(address(cfgImpl), cfgInit))
		);

		// Vaults behind a UUPS proxy.
		StreamVaults svImpl = new StreamVaults();
		bytes memory svInit = abi.encodeCall(
			StreamVaults.initialize,
			(deployer, address(config))
		);
		vaults = StreamVaults(address(new ERC1967Proxy(address(svImpl), svInit)));

		vm.stopPrank();
	}

	function _defaultRules() internal view returns (Types.UserRules memory r) {
		address[] memory targets = new address[](1);
		targets[0] = address(weth);
		r = Types.UserRules({
			maxSlippageBps: 100,
			minTradeAmount: 1e6,
			settlementAddress: settlement,
			targetTokens: targets
		});
	}
}
