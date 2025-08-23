// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ISwapAdapter} from "reka-common/adapters/ISwapAdapter.sol";
import {IERC20} from "reka-common/utils/IERC20.sol";

contract MockSwapAdapter is ISwapAdapter {
    IERC20 public immutable USDT;
    IERC20 public immutable USDe;
    uint256 public rateUSDTtoUSDe = 1e12; // 6d->18d (1:1)

    constructor(address usdt, address usde) {
        USDT = IERC20(usdt);
        USDe = IERC20(usde);
    }

    function setRate(uint256 usdtToUsde) external { rateUSDTtoUSDe = usdtToUsde; }

    function quoteUSDTtoUSDe(uint256 usdtIn) external view returns (uint256) {
        // 1 USDT(6d) => 1e12 USDe(18d)
        return usdtIn * 1e12;
    }

    function quoteUSDetoUSDT(uint256 usdeIn) external view returns (uint256) {
        return usdeIn / 1e12;
    }

    function swapExactUSDTForUSDe(uint256 usdtIn, uint256 minUsdeOut, address to) external returns (uint256) {
        require(USDT.transferFrom(msg.sender, address(this), usdtIn), "pull USDT");
        uint256 out = usdtIn * 1e12;
        require(out >= minUsdeOut, "min");
        require(USDe.transfer(to, out), "xfer USDe");
        return out;
    }

    function swapExactUSDeForUSDT(uint256 usdeIn, uint256 minUsdtOut, address to) external returns (uint256) {
        require(USDe.transferFrom(msg.sender, address(this), usdeIn), "pull USDe");
        uint256 out = usdeIn / 1e12;
        require(out >= minUsdtOut, "min");
        require(USDT.transfer(to, out), "xfer USDT");
        return out;
    }
}
