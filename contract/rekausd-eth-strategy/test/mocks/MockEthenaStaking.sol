// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IEthenaStakingAdapter} from "../../src/adapters/IEthenaStakingAdapter.sol";
import {IERC20} from "../../src/utils/IERC20.sol";
import {MockSUSDe} from "./MockTokens.sol";

contract MockEthenaStaking is IEthenaStakingAdapter {
    IERC20 public USDe;
    MockSUSDe public sUSDe;

    uint256 public exchangeRateWad = 1e18; // sUSDe:USDe = 1 initially

    constructor(address usde, address s) { USDe = IERC20(usde); sUSDe = MockSUSDe(s); }

    function setExchangeRate(uint256 wad) external { exchangeRateWad = wad; }

    function stake(uint256 usdeAmount) external returns (uint256 sharesMinted) {
        require(USDe.transferFrom(msg.sender, address(this), usdeAmount), "pull");
        // shares = usdeAmount / rate
        sharesMinted = usdeAmount * 1e18 / exchangeRateWad;
        sUSDe.mint(msg.sender, sharesMinted);
    }

    function unstake(uint256 sShares) external returns (uint256 usdeOut) {
        sUSDe.burn(msg.sender, sShares);
        usdeOut = sShares * exchangeRateWad / 1e18;
        require(USDe.transfer(msg.sender, usdeOut), "push");
    }

    function sUSDeBalance() external view returns (uint256) {
        return sUSDe.balanceOf(msg.sender);
    }

    function previewRedeem(uint256 sShares) external view returns (uint256) {
        return sShares * exchangeRateWad / 1e18;
    }
}
