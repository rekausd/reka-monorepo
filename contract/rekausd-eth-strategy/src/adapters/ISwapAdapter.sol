// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface ISwapAdapter {
  function swapExactUSDTForUSDe(uint256 usdtIn, uint256 minUsdeOut, address to) external returns (uint256);
  function swapExactUSDeForUSDT(uint256 usdeIn, uint256 minUsdtOut, address to) external returns (uint256);
  function quoteUSDTtoUSDe(uint256 usdtIn) external view returns (uint256);
  function quoteUSDetoUSDT(uint256 usdeIn) external view returns (uint256);
}
