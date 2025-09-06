// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStrategyModule} from "./IStrategyModule.sol";

contract PendleModule is IStrategyModule {
    IERC20 public immutable USDT;
    address public immutable owner;
    bool public investEnabled = true;
    
    // Placeholder for Pendle integration
    // In production: router, market, PT, YT addresses

    constructor(address usdt /* + router, market, PT, YT addrs as needed */) {
        USDT = IERC20(usdt);
        owner = msg.sender;
        // Future: approvals to Pendle router here
    }

    function healthy() external view returns (bool) { 
        return investEnabled; 
    }
    
    function setInvestEnabled(bool v) external { 
        require(msg.sender == owner, "owner"); 
        investEnabled = v; 
    }

    function apyBps() external pure returns (uint16) { 
        return 1300; // 13% demo value
    }

    function totalAssetsUSDT() public view returns (uint256) {
        // TODO: In production, calculate value of PT/LP positions
        // For now, just return USDT balance
        return USDT.balanceOf(address(this));
    }
    
    function previewDepositUSDT(uint256 v) external pure returns (uint256) { 
        return v; 
    }
    
    function previewWithdrawUSDT(uint256 v) external pure returns (uint256) { 
        return v; 
    }

    function depositUSDT(uint256 usdtAmount, uint16 /*slippageBps*/) external returns (uint256) {
        if (!investEnabled || usdtAmount == 0) return 0;
        
        require(USDT.transferFrom(msg.sender, address(this), usdtAmount), "tf");
        
        // TODO: Implement Pendle investment logic
        // 1. Swap USDT -> underlying asset (e.g., sUSDe)
        // 2. Deposit to Pendle market
        // 3. Buy PT or provide liquidity
        
        return usdtAmount;
    }
    
    function withdrawUSDT(uint256 usdtAmount, uint16 /*slippageBps*/) external returns (uint256) {
        if (usdtAmount == 0) return 0;
        
        uint256 balance = USDT.balanceOf(address(this));
        if (balance == 0) return 0;
        
        uint256 toReturn = balance >= usdtAmount ? usdtAmount : balance;
        
        // TODO: Implement Pendle withdrawal logic
        // 1. Sell PT or remove liquidity
        // 2. Withdraw from Pendle market
        // 3. Swap underlying -> USDT
        
        require(USDT.transfer(msg.sender, toReturn), "xfer");
        return toReturn;
    }
}