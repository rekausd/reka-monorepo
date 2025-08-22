// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "./IERC20.sol";

library SafeERC20Compat {
    function _call(IERC20 token, bytes memory data) private {
        (bool ok, bytes memory ret) = address(token).call(data);
        require(ok && (ret.length == 0 || abi.decode(ret, (bool))), "ERC20_OP_FAIL");
    }

    function safeTransfer(IERC20 token, address to, uint256 amt) internal {
        _call(token, abi.encodeWithSelector(token.transfer.selector, to, amt));
    }
    function safeTransferFrom(IERC20 token, address from, address to, uint256 amt) internal {
        _call(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, amt));
    }
    function safeApprove(IERC20 token, address to, uint256 amt) internal {
        _call(token, abi.encodeWithSelector(token.approve.selector, to, amt));
    }
}
