// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStrategyModule} from "../../../../src/eth/strategy/modules/IStrategyModule.sol";

contract MockModule is IStrategyModule {
    IERC20 public immutable USDT;
    uint256 public internalBalance;
    bool public isHealthy = true;
    uint16 public apy = 1000; // 10%
    
    constructor(address usdt) {
        USDT = IERC20(usdt);
    }
    
    function setHealthy(bool h) external {
        isHealthy = h;
    }
    
    function setApy(uint16 bps) external {
        apy = bps;
    }
    
    function setInternalBalance(uint256 bal) external {
        internalBalance = bal;
    }
    
    function healthy() external view returns (bool) {
        return isHealthy;
    }
    
    function apyBps() external view returns (uint16) {
        return apy;
    }
    
    function totalAssetsUSDT() external view returns (uint256) {
        return internalBalance;
    }
    
    function previewDepositUSDT(uint256 usdtAmount) external pure returns (uint256) {
        return usdtAmount;
    }
    
    function previewWithdrawUSDT(uint256 usdtAmount) external pure returns (uint256) {
        return usdtAmount;
    }
    
    function depositUSDT(uint256 usdtAmount, uint16 /*slippageBps*/) external returns (uint256) {
        if (!isHealthy || usdtAmount == 0) return 0;
        
        require(USDT.transferFrom(msg.sender, address(this), usdtAmount), "tf");
        internalBalance += usdtAmount;
        return usdtAmount;
    }
    
    function withdrawUSDT(uint256 usdtAmount, uint16 /*slippageBps*/) external returns (uint256) {
        if (usdtAmount == 0) return 0;
        
        uint256 toWithdraw = usdtAmount > internalBalance ? internalBalance : usdtAmount;
        if (toWithdraw == 0) return 0;
        
        internalBalance -= toWithdraw;
        
        // Get actual USDT balance
        uint256 actualBalance = USDT.balanceOf(address(this));
        if (actualBalance < toWithdraw) {
            toWithdraw = actualBalance;
        }
        
        require(USDT.transfer(msg.sender, toWithdraw), "xfer");
        return toWithdraw;
    }
    
    // Helper to fund the module for testing
    function fundModule(uint256 amount) external {
        require(USDT.transferFrom(msg.sender, address(this), amount), "fund");
    }
}