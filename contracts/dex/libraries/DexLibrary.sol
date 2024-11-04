// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;
import "../MultiTokenPoolAmmV1.sol";

library DexLibrary {
    function getPoolId(
        address tokenA,
        address tokenB
    ) internal pure returns (bytes32) {
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        return keccak256(abi.encodePacked(token0, token1));
    }

    function sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function calculateAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 feeNumerator,
        uint256 feeDenominator,
        address tokenIn,
        address feeToken // Token from which platform fee is deducted
    ) internal pure returns (uint256) {
        require(amountIn < reserveIn, "Invalid input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        if (tokenIn == feeToken) {
            uint256 amountInWithFee = amountIn * feeNumerator;
            uint256 numerator = amountInWithFee * reserveOut;
            uint256 denominator = (reserveIn * feeDenominator) +
                amountInWithFee;

            return numerator / denominator;
        } else {
            uint256 numerator = amountIn * reserveOut;
            uint256 denominator = (reserveIn) + amountIn;

            uint256 amountOut = numerator / denominator;

            return (amountOut * feeNumerator) / feeDenominator;
        }
    }

    function calculateAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 feeNumerator,
        uint256 feeDenominator,
        address tokenOut,
        address feeToken // Token from which platform fee is deducted
    ) internal pure returns (uint256) {
        require(amountOut > 0, "Invalid output amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        if (tokenOut == feeToken) {
            uint256 numerator = reserveIn * amountOut * feeNumerator;
            uint256 denominator = (reserveOut - amountOut) * feeDenominator;
            return (numerator / denominator);
        } else {
            uint256 numerator = reserveIn * amountOut * feeDenominator;
            uint256 denominator = (reserveOut - amountOut) * feeNumerator;
            return (numerator / denominator) + 1;
        }
    }

    function updateReserves(
        MultiTokenPoolAmmV1.Pool storage pool,
        address tokenIn,
        uint256 amountIn,
        uint256 amountOut
    ) internal {
        if (tokenIn == pool.token0) {
            pool.reserve0 += amountIn;
            pool.reserve1 -= amountOut;
        } else {
            pool.reserve1 += amountIn;
            pool.reserve0 -= amountOut;
        }
    }
}
