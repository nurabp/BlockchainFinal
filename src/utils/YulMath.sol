// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library YulMath {
    function minSolidity(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function minYul(uint256 a, uint256 b) internal pure returns (uint256 r) {
        assembly {
            r := xor(b, mul(xor(a, b), lt(a, b)))
        }
    }

    function sqrt(uint256 x) internal pure returns (uint256 z) {
        if (x == 0) return 0;
        z = x;
        uint256 y = (x + 1) / 2;
        while (y < z) {
            z = y;
            y = (x / y + y) / 2;
        }
    }
}

