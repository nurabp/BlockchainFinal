// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20Base } from "../token/ERC20Base.sol";
import { IERC20 } from "../interfaces/IERC20.sol";
import { ReentrancyGuard } from "../utils/ReentrancyGuard.sol";
import { YulMath } from "../utils/YulMath.sol";

contract ConstantProductAMM is ERC20Base, ReentrancyGuard {
    IERC20 public immutable token0;
    IERC20 public immutable token1;
    uint112 public reserve0;
    uint112 public reserve1;
    uint256 public constant FEE_BPS = 30;
    uint256 public constant BPS = 10_000;

    event Mint(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);
    event Burn(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);
    event Swap(
        address indexed trader, address indexed tokenIn, uint256 amountIn, uint256 amountOut
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor(IERC20 token0_, IERC20 token1_) ERC20Base("RWA AMM LP", "rwaLP", 18) {
        require(address(token0_) != address(token1_), "SAME_TOKEN");
        token0 = token0_;
        token1 = token1_;
    }

    function addLiquidity(uint256 amount0, uint256 amount1, uint256 minLiquidity)
        external
        nonReentrant
        returns (uint256 liquidity)
    {
        require(amount0 > 0 && amount1 > 0, "ZERO_AMOUNT");
        require(token0.transferFrom(msg.sender, address(this), amount0), "T0_IN");
        require(token1.transferFrom(msg.sender, address(this), amount1), "T1_IN");
        if (totalSupply < 1) {
            liquidity = YulMath.sqrt(amount0 * amount1);
        } else {
            liquidity =
                YulMath.minYul(amount0 * totalSupply / reserve0, amount1 * totalSupply / reserve1);
        }
        require(liquidity >= minLiquidity && liquidity > 0, "SLIPPAGE");
        _mint(msg.sender, liquidity);
        _sync();
        emit Mint(msg.sender, amount0, amount1, liquidity);
    }

    function removeLiquidity(uint256 liquidity, uint256 min0, uint256 min1)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        require(liquidity > 0, "ZERO_LIQUIDITY");
        amount0 = liquidity * reserve0 / totalSupply;
        amount1 = liquidity * reserve1 / totalSupply;
        require(amount0 >= min0 && amount1 >= min1, "SLIPPAGE");
        _burn(msg.sender, liquidity);
        reserve0 -= uint112(amount0);
        reserve1 -= uint112(amount1);
        emit Sync(reserve0, reserve1);
        require(token0.transfer(msg.sender, amount0), "T0_OUT");
        require(token1.transfer(msg.sender, amount1), "T1_OUT");
        emit Burn(msg.sender, amount0, amount1, liquidity);
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minAmountOut)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        uint256 kBefore = uint256(reserve0) * uint256(reserve1);
        require(tokenIn == address(token0) || tokenIn == address(token1), "BAD_TOKEN");
        require(amountIn > 0, "ZERO_AMOUNT");
        bool zeroForOne = tokenIn == address(token0);
        (IERC20 input, IERC20 output, uint112 reserveIn, uint112 reserveOut) =
            zeroForOne ? (token0, token1, reserve0, reserve1) : (token1, token0, reserve1, reserve0);
        uint256 amountInWithFee = amountIn * (BPS - FEE_BPS);
        amountOut = amountInWithFee * reserveOut / (reserveIn * BPS + amountInWithFee);
        require(amountOut >= minAmountOut && amountOut > 0, "SLIPPAGE");
        if (zeroForOne) {
            reserve0 += uint112(amountIn);
            reserve1 -= uint112(amountOut);
        } else {
            reserve1 += uint112(amountIn);
            reserve0 -= uint112(amountOut);
        }
        require(uint256(reserve0) * uint256(reserve1) >= kBefore, "K");
        emit Sync(reserve0, reserve1);
        require(input.transferFrom(msg.sender, address(this), amountIn), "INPUT_IN");
        require(output.transfer(msg.sender, amountOut), "OUTPUT_OUT");
        emit Swap(msg.sender, tokenIn, amountIn, amountOut);
    }

    function _sync() internal {
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        require(balance0 <= type(uint112).max && balance1 <= type(uint112).max, "OVERFLOW");
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        emit Sync(reserve0, reserve1);
    }
}
