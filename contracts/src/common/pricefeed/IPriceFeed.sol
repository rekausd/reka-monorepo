// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Returns quotePerBase in 1e18 (QUOTE per 1 BASE) and updatedAt
interface IPriceFeed {
    function priceWad() external view returns (uint256 priceWad, uint64 updatedAt);
    function heartbeat() external view returns (uint64);
    function quote(uint256 baseAmount, uint8 baseDecimals, uint8 quoteDecimals)
        external view returns (uint256 quoteAmount, uint64 updatedAt);
}