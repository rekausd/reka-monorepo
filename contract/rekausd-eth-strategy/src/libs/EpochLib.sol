// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library EpochLib {
    uint256 internal constant WEEK = 7 days;
    error RolloverNotDue();

    struct EpochState {
        uint64 currentEpoch;
        uint64 epochStart;
        uint64 epochDuration;
        uint64 nextRolloverAt;
    }

    function init(EpochState storage s) internal {
        s.currentEpoch = 0;
        s.epochStart = uint64(block.timestamp);
        s.epochDuration = uint64(WEEK);
        s.nextRolloverAt = uint64(block.timestamp + WEEK);
    }

    function canRollover(EpochState storage s) internal view returns (bool) {
        return block.timestamp >= s.nextRolloverAt;
    }

    function tick(EpochState storage s) internal {
        if (block.timestamp < s.nextRolloverAt) revert RolloverNotDue();
        s.currentEpoch += 1;
        s.nextRolloverAt += s.epochDuration;
    }
}
