// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IStargateAdapter} from "reka-common/adapters/IStargateAdapter.sol";

contract MockStargate is IStargateAdapter {
    event Bridged(uint16 dst, address to, uint256 amt);

    function bridgeUSDT(uint16 dstChainId, address dstAddress, uint256 amount, uint256 /*minAmountLD*/, bytes calldata /*extra*/) external payable {
        emit BridgeUSDT(dstChainId, dstAddress, amount);
        emit Bridged(dstChainId, dstAddress, amount);
    }
}
