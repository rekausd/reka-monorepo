// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IBridgeAdapter} from "reka-kaia/interfaces/IBridgeAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice Simple mock adapter that only emits events and tracks last bridged amount.
contract MockStargateAdapter is IBridgeAdapter {
    address public immutable usdt;
    uint256 public lastBridgedAmount;
    uint64 public lastBridgedEpoch;

    constructor(address _usdt) {
        require(_usdt != address(0), "usdt=0");
        usdt = _usdt;
    }

    function bridgeUSDT(uint256 amount, uint64 epoch) external override {
        // No external bridge calls; just emit event and record values
        lastBridgedAmount = amount;
        lastBridgedEpoch = epoch;
        emit BridgeInitiated(usdt, amount, epoch);
    }
}
