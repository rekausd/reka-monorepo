// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library EpochLib {
    function currentEpochIndex(uint64 start, uint64 duration) internal view returns (uint64) {
        if (block.timestamp < start) return 0;
        unchecked {
            return uint64((block.timestamp - start) / duration);
        }
    }

    function epochStartTime(uint64 start, uint64 duration, uint64 epochIndex) internal pure returns (uint64) {
        unchecked {
            return start + duration * epochIndex;
        }
    }
}
