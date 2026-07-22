// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ISwapRouter02} from "../../src/core/interfaces/external/ISwapRouter02.sol";

/// @title MockUniswapRouter
/// @notice Stub Uniswap v3 SwapRouter02 for testing. On `exactInputSingle`:
///         - Pulls `params.amountIn` of `params.tokenIn` from the caller
///           (SmartAccountDCA) via a plain ERC20 allowance (transferFrom).
///         - Transfers the configured `amountOut` of tokenOut to
///           `params.recipient` (the forced recipient set by the smart account).
/// @dev The test setup must pre-fund this router with sufficient tokenOut.
///      Configure via `configure()` before each swap.
contract MockUniswapRouter is ISwapRouter02 {
    using SafeERC20 for IERC20;

    address public tokenIn;
    address public tokenOut;
    uint256 public amountOut;
    bool public shouldFail;

    /// @notice Records the recipient the contract passed on the last swap so tests
    ///         can assert the forced-recipient invariant.
    address public lastRecipient;

    function configure(
        address tokenIn_,
        address tokenOut_,
        uint256 amountOut_,
        bool shouldFail_
    ) external {
        tokenIn = tokenIn_;
        tokenOut = tokenOut_;
        amountOut = amountOut_;
        shouldFail = shouldFail_;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable override returns (uint256) {
        require(!shouldFail, "MockRouter: forced swap failure");

        lastRecipient = params.recipient;

        // Pull exactly amountIn of tokenIn from the caller via ERC20 allowance.
        if (params.amountIn > 0) {
            IERC20(params.tokenIn).safeTransferFrom(
                msg.sender,
                address(this),
                params.amountIn
            );
        }

        // Deliver the configured output to the recipient the router was told to
        // use (which the SmartAccountDCA hardcodes to itself).
        if (amountOut > 0) {
            IERC20(params.tokenOut).safeTransfer(params.recipient, amountOut);
        }

        return amountOut;
    }
}

/// @dev Minimal mintable ERC20 used as tokenOut in tests.
///      Deployed separately so the router can hold a pre-funded balance.
contract MockMintableERC20 is IERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public override totalSupply;
    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    constructor(string memory name_, string memory symbol_) {
        name = name_;
        symbol = symbol_;
    }

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        require(balanceOf[msg.sender] >= amount, "MockERC20: insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external override returns (bool) {
        require(balanceOf[from] >= amount, "MockERC20: insufficient balance");
        require(allowance[from][msg.sender] >= amount, "MockERC20: insufficient allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}
