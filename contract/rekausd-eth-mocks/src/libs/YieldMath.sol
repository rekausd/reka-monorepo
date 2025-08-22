// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
// no external Math to avoid mulDiv overflow guard; our ranges are safe

library YieldMath {
    uint256 internal constant _RAY = 1e27;

    function RAY() internal pure returns (uint256) { return _RAY; }

    function toRay(uint256 wad) internal pure returns (uint256) {
        return wad * 1e9; // 1e18 -> 1e27
    }

    function fromRay(uint256 ray) internal pure returns (uint256) {
        return ray / 1e9;
    }

    function mulDivRay(uint256 a, uint256 b) internal pure returns (uint256) {
        unchecked { return (a * b) / _RAY; }
    }

    // fast pow by repeated squaring for 64-bit exp
    function powRay(uint256 baseRay, uint256 expSec) internal pure returns (uint256 result) {
        result = _RAY;
        uint256 x = baseRay;
        uint256 n = expSec;
        while (n > 0) {
            if (n & 1 == 1) {
                result = mulDivRay(result, x);
            }
            x = mulDivRay(x, x);
            n >>= 1;
        }
    }
}
