// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IEthenaStakingAdapter {
  function stake(uint256 usdeAmount) external returns (uint256 sharesMinted);
  function unstake(uint256 sShares) external returns (uint256 usdeOut);
  function sUSDeBalance() external view returns (uint256);
  function previewRedeem(uint256 sShares) external view returns (uint256 usdeOut);
}
