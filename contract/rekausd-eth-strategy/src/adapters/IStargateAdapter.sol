// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IStargateAdapter {
  event BridgeUSDT(uint16 dstChainId, address dstAddress, uint256 amount);
  function bridgeUSDT(uint16 dstChainId, address dstAddress, uint256 amount, uint256 minAmountLD, bytes calldata extra) external payable;
}
