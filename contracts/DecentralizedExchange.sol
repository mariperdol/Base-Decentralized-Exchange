// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
 
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ILiquidityPool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112);
    function swap(uint256 amountOut0, uint256 amountOut1, address to) external;
}

contract DecentralizedExchange is Ownable {
    using SafeERC20 for IERC20;

    uint256 public swapFeeBps = 30; // 0.30%

    event SwapFeeUpdated(uint256 oldFee, uint256 newFee);
    event SwapExecuted(
        address indexed pool,
        address indexed sender,
        address indexed tokenIn,
        uint256 amountIn,
        uint256 amountOut,
        address to,
        uint256 deadline
    );

    constructor() Ownable(msg.sender) {}

    function setSwapFee(uint256 newFee) external onlyOwner {
        require(newFee <= 100, "too high");
        uint256 oldFee = swapFeeBps;
        swapFeeBps = newFee;
        emit SwapFeeUpdated(oldFee, newFee);
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) public view returns (uint256) {
        require(amountIn > 0, "in=0");
        require(reserveIn > 0 && reserveOut > 0, "bad reserves");

        uint256 amountInWithFee = amountIn * (10000 - swapFeeBps);
        return (amountInWithFee * reserveOut) / (reserveIn * 10000 + amountInWithFee);
    }

    function quoteExactInput(
        address pool,
        address tokenIn,
        uint256 amountIn
    ) external view returns (uint256 amountOut) {
        ILiquidityPool p = ILiquidityPool(pool);
        (uint112 r0, uint112 r1) = p.getReserves();

        if (tokenIn == p.token0()) {
            return getAmountOut(amountIn, uint256(r0), uint256(r1));
        } else if (tokenIn == p.token1()) {
            return getAmountOut(amountIn, uint256(r1), uint256(r0));
        } else {
            revert("bad tokenIn");
        }
    }

    function swapExactTokensForTokens(
        address pool,
        address tokenIn,
        uint256 amountIn,
        uint256 minOut,
        address to,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        require(block.timestamp <= deadline, "expired");
        require(to != address(0), "to=0");

        ILiquidityPool p = ILiquidityPool(pool);
        address token0 = p.token0();
        address token1 = p.token1();
        (uint112 r0, uint112 r1) = p.getReserves();

        if (tokenIn == token0) {
            amountOut = getAmountOut(amountIn, uint256(r0), uint256(r1));
            require(amountOut >= minOut, "slippage");

            IERC20(token0).safeTransferFrom(msg.sender, pool, amountIn);
            p.swap(0, amountOut, to);
        } else if (tokenIn == token1) {
            amountOut = getAmountOut(amountIn, uint256(r1), uint256(r0));
            require(amountOut >= minOut, "slippage");

            IERC20(token1).safeTransferFrom(msg.sender, pool, amountIn);
            p.swap(amountOut, 0, to);
        } else {
            revert("bad tokenIn");
        }

        emit SwapExecuted(pool, msg.sender, tokenIn, amountIn, amountOut, to, deadline);
    }
}
