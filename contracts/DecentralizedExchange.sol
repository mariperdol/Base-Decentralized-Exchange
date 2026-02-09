// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
  Educational router:
  - swapExactTokensForTokens
  - minOut slippage protection
*/

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IBaseV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112);
    function swap(uint256 amountOut0, uint256 amountOut1, address to) external;
}

contract BaseSimpleRouter {
    using SafeERC20 for IERC20;

    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256) {
        require(amountIn > 0, "in=0");
        require(reserveIn > 0 && reserveOut > 0, "bad reserves");
        uint256 amountInWithFee = amountIn * 997;
        return (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee);
    }

    function swapExactTokensForTokens(
        address pair,
        address tokenIn,
        uint256 amountIn,
        uint256 minOut,
        address to
    ) external returns (uint256 amountOut) {
        require(to != address(0), "to=0");
        IBaseV2Pair p = IBaseV2Pair(pair);

        (uint112 r0, uint112 r1) = p.getReserves();
        address t0 = p.token0();
        address t1 = p.token1();
        require(tokenIn == t0 || tokenIn == t1, "tokenIn not in pair");

        (uint256 reserveIn, uint256 reserveOut) = tokenIn == t0 ? (uint256(r0), uint256(r1)) : (uint256(r1), uint256(r0));
        amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= minOut, "slippage");

        IERC20(tokenIn).safeTransferFrom(msg.sender, pair, amountIn); 

        if (tokenIn == t0) {
            p.swap(0, amountOut, to);
        } else {
            p.swap(amountOut, 0, to);
        }
    }
}
