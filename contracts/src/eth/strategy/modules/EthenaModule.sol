// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStrategyModule} from "./IStrategyModule.sol";
import {ISwapAdapter} from "reka-common/adapters/ISwapAdapter.sol";
import {IEthenaStakingAdapter} from "reka-common/adapters/IEthenaStakingAdapter.sol";

contract EthenaModule is IStrategyModule {
    IERC20 public immutable USDT;
    IERC20 public immutable USDe;
    IERC20 public immutable sUSDe;
    ISwapAdapter public immutable swap;
    IEthenaStakingAdapter public immutable stake;
    address public immutable owner;
    bool public investEnabled = true;

    constructor(
        address usdt, 
        address usde, 
        address s, 
        address swap_, 
        address stake_
    ) {
        USDT = IERC20(usdt);
        USDe = IERC20(usde);
        sUSDe = IERC20(s);
        swap = ISwapAdapter(swap_);
        stake = IEthenaStakingAdapter(stake_);
        owner = msg.sender;
        USDT.approve(swap_, type(uint256).max);
        USDe.approve(address(stake_), type(uint256).max);
        USDe.approve(swap_, type(uint256).max);
    }

    function healthy() external view returns (bool) { 
        return investEnabled; 
    }
    
    function setInvestEnabled(bool v) external { 
        require(msg.sender == owner, "owner"); 
        investEnabled = v; 
    }

    function apyBps() external pure returns (uint16) { 
        return 1100; // 11% demo value
    }

    function totalAssetsUSDT() public view returns (uint256) {
        uint256 cash = USDT.balanceOf(address(this));
        uint256 sBal = sUSDe.balanceOf(address(this));
        if (sBal == 0) return cash;
        uint256 usde = stake.previewRedeem(sBal);
        uint256 usdt = swap.quoteUSDetoUSDT(usde);
        return cash + usdt;
    }

    function previewDepositUSDT(uint256 usdtAmount) external view returns (uint256) {
        // Simplified preview - actual may vary due to slippage
        return usdtAmount;
    }

    function previewWithdrawUSDT(uint256 usdtAmount) external view returns (uint256) {
        uint256 sBal = sUSDe.balanceOf(address(this));
        if (sBal == 0) return 0;
        return usdtAmount;
    }

    function depositUSDT(uint256 usdtAmount, uint16 slippageBps) external returns (uint256 accepted) {
        if (!investEnabled || usdtAmount == 0) return 0;
        
        // Pull USDT from caller (strategy)
        require(USDT.transferFrom(msg.sender, address(this), usdtAmount), "tf");
        
        // Swap USDT -> USDe
        uint256 quote = swap.quoteUSDTtoUSDe(usdtAmount);
        uint256 minUsde = (quote * (10_000 - slippageBps)) / 10_000;
        uint256 usdeOut = swap.swapExactUSDTForUSDe(usdtAmount, minUsde, address(this));
        
        // Stake USDe -> sUSDe
        stake.stake(usdeOut);
        
        return usdtAmount;
    }

    function withdrawUSDT(uint256 usdtAmount, uint16 slippageBps) external returns (uint256 returned) {
        if (usdtAmount == 0) return 0;
        
        uint256 sBal = sUSDe.balanceOf(address(this));
        if (sBal == 0) return 0;
        
        // Calculate proportional sUSDe to redeem
        uint256 tvl = totalAssetsUSDT();
        uint256 sToRedeem = tvl > 0 ? (sBal * usdtAmount) / tvl : sBal;
        if (sToRedeem > sBal) sToRedeem = sBal;
        
        // Unstake sUSDe -> USDe
        uint256 usdeOut = stake.unstake(sToRedeem);
        
        // Swap USDe -> USDT
        uint256 quote = swap.quoteUSDetoUSDT(usdeOut);
        uint256 minUsdt = (quote * (10_000 - slippageBps)) / 10_000;
        uint256 usdtOut = swap.swapExactUSDeForUSDT(usdeOut, minUsdt, address(this));
        
        // Push back to strategy
        require(USDT.transfer(msg.sender, usdtOut), "xfer");
        
        return usdtOut;
    }
}