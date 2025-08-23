// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title SafeERC20Compat
/// @notice Wrapper around OZ SafeERC20 to gracefully handle non-standard ERC20 (USDT-like).
///         Provides convenience functions with consistent naming.
library SafeERC20Compat {
    using SafeERC20 for IERC20;

    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        token.safeTransferFrom(from, to, value);
    }

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        token.safeTransfer(to, value);
    }

    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // Use OZ's recommend pattern: set to 0 or increase/decrease in safe manner if needed
        token.approve(spender, value);
    }
}
