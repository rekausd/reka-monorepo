// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IPermit2
/// @notice Minimal Permit2 (AllowanceTransfer) interface for single-permit + transferFrom
/// @dev Interface for Uniswap's Permit2 contract to enable gasless approvals
interface IPermit2 {
    /// @notice Details for a token permit
    struct PermitDetails {
        address token;      // ERC20 token address
        uint160 amount;     // Amount to permit (max uint160)
        uint48 expiration;  // Unix timestamp when permit expires
        uint48 nonce;       // Unique nonce for permit
    }

    /// @notice Single token permit data
    struct PermitSingle {
        PermitDetails details;  // Token permit details
        address spender;        // Address allowed to spend
        uint256 sigDeadline;    // Unix timestamp when signature expires
    }

    /// @notice Sets permit for a single token/amount. Verifies EIP-712 signature from `owner`
    /// @param owner The token owner who signed the permit
    /// @param permitSingle The permit data
    /// @param signature The EIP-712 signature
    function permit(
        address owner,
        PermitSingle calldata permitSingle,
        bytes calldata signature
    ) external;

    /// @notice Transfer details for batch transfers
    struct TransferDetails {
        address from;    // Source address
        address to;      // Destination address  
        uint160 amount;  // Amount to transfer
        address token;   // Token address
    }

    /// @notice Transfer tokens based on existing permits/allowances
    /// @param transferDetails Array of transfer operations to execute
    function transferFrom(TransferDetails[] calldata transferDetails) external;

    /// @notice Returns the EIP-712 domain separator
    /// @return The domain separator bytes32
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}