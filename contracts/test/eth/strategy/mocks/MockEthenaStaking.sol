// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IEthenaStakingAdapter} from "reka-common/adapters/IEthenaStakingAdapter.sol";
import {MockUSDe, MockSUSDe} from "./MockTokens.sol";

contract MockEthenaStaking is IEthenaStakingAdapter {
    MockUSDe public USDe;
    MockSUSDe public sUSDe;

    uint256 public exchangeRateWad = 1e18; // sUSDe:USDe = 1 initially

    constructor(address usde, address s) { USDe = MockUSDe(usde); sUSDe = MockSUSDe(s); }

    function setExchangeRate(uint256 wad) external { exchangeRateWad = wad; }

    function stake(uint256 usdeAmount) external returns (uint256 sharesMinted) {
        require(USDe.transferFrom(msg.sender, address(this), usdeAmount), "pull");
        // shares = usdeAmount / rate
        sharesMinted = usdeAmount * 1e18 / exchangeRateWad;
        // Adapter holds the sUSDe it stakes on behalf of the strategy
        sUSDe.mint(address(this), sharesMinted);
    }

    function unstake(uint256 sShares) external returns (uint256 usdeOut) {
        sUSDe.burn(address(this), sShares);
        usdeOut = sShares * exchangeRateWad / 1e18;
        // For testing, materialize USDe out of the staking position
        USDe.mint(address(this), usdeOut);
        require(USDe.transfer(msg.sender, usdeOut), "push");
    }

    function sUSDeBalance() external view returns (uint256) {
        return sUSDe.balanceOf(address(this));
    }

    function previewRedeem(uint256 sShares) external view returns (uint256) {
        return sShares * exchangeRateWad / 1e18;
    }
}
