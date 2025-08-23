// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBridgeAdapter {
    event BridgeInitiated(address indexed token, uint256 amount, uint64 epoch);

    function bridgeUSDT(uint256 amount, uint64 epoch) external;
}
