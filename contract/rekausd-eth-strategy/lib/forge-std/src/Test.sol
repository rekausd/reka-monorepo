// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Test {
    function assertTrue(bool b) internal pure { require(b, "!true"); }
    function assertFalse(bool b) internal pure { require(!b, "!false"); }
    function assertGt(uint256 a, uint256 b) internal pure { require(a > b, "!gt"); }
}
