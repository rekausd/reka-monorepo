// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Module must accept USDT and return USDT on redeem. Accounting in USDT terms.
interface IStrategyModule {
    /// @dev total assets (USDT-equivalent) managed by this module
    function totalAssetsUSDT() external view returns (uint256);

    /// @dev deposit USDT into module; returns amount accepted (may be < requested)
    function depositUSDT(uint256 usdtAmount, uint16 slippageBps) external returns (uint256 accepted);

    /// @dev withdraw USDT from module; returns amount returned (may be < requested due to slippage/caps)
    function withdrawUSDT(uint256 usdtAmount, uint16 slippageBps) external returns (uint256 returned);

    /// @dev preview values (no state change)
    function previewDepositUSDT(uint256 usdtAmount) external view returns (uint256 expected);
    function previewWithdrawUSDT(uint256 usdtAmount) external view returns (uint256 expected);

    /// @dev health flag: true if module can invest new funds; false if read-only / redemption-only
    function healthy() external view returns (bool);

    /// @dev optional APY basis points for UI/sizing; 0 if unknown
    function apyBps() external view returns (uint16);
}