// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPermit2} from "../common/permit2/IPermit2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IRkMint {
    function mint(address to, uint256 amt) external;
    function burn(address from, uint256 amt) external;
}

/// @title SimpleRekaUSDVault 
/// @notice Simplified vault for KAIA testnet deployment - deposit with Permit2 support
contract SimpleRekaUSDVault is ReentrancyGuard {
    error InvalidToken();
    error ZeroAmount();
    error Permit2NotSet();
    error InsufficientBalance();
    
    event Deposit(address indexed owner, uint256 amount);
    event DepositWithPermit2(address indexed owner, uint256 amount, uint256 sigDeadline);
    event WithdrawalRequested(address indexed owner, uint256 amount, uint256 epoch);
    event WithdrawalClaimed(address indexed owner, uint256 amount);
    
    IERC20 public immutable USDT;
    IRkMint public immutable rkUSDT;
    IPermit2 public immutable PERMIT2;
    
    // Epoch configuration (10-day periods)
    uint64 public immutable epoch0Start;
    uint64 public immutable epochDuration = 10 days;
    
    // Simple withdrawal tracking
    mapping(address => uint256) public pendingWithdrawals;
    mapping(address => uint256) public withdrawalEpoch;
    mapping(address => uint256) public claimable;
    
    constructor(address usdt, address rkusdt, address permit2) {
        require(usdt != address(0) && rkusdt != address(0), "Zero address");
        USDT = IERC20(usdt);
        rkUSDT = IRkMint(rkusdt);
        PERMIT2 = IPermit2(permit2);
        
        // Align epoch 0 to today UTC 00:00
        uint64 todayUtc0 = uint64(block.timestamp - (block.timestamp % 1 days));
        epoch0Start = todayUtc0;
    }
    
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();
        require(USDT.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        rkUSDT.mint(msg.sender, amount);
        emit Deposit(msg.sender, amount);
    }
    
    function depositWithPermit2(
        address owner,
        address token,
        uint256 amount,
        uint256 sigDeadline,
        bytes calldata signature
    ) external nonReentrant {
        if (address(PERMIT2) == address(0)) revert Permit2NotSet();
        if (token != address(USDT)) revert InvalidToken();
        if (amount == 0) revert ZeroAmount();
        
        // Build permit details
        IPermit2.PermitDetails memory det = IPermit2.PermitDetails({
            token: token,
            amount: _u160(amount),
            expiration: uint48(block.timestamp + 7 days),
            nonce: 0
        });
        
        IPermit2.PermitSingle memory single = IPermit2.PermitSingle({
            details: det,
            spender: address(this),
            sigDeadline: sigDeadline
        });
        
        // Execute permit
        PERMIT2.permit(owner, single, signature);
        
        // Transfer via Permit2
        IPermit2.TransferDetails[] memory ops = new IPermit2.TransferDetails[](1);
        ops[0] = IPermit2.TransferDetails({
            from: owner,
            to: address(this),
            amount: _u160(amount),
            token: token
        });
        PERMIT2.transferFrom(ops);
        
        // Mint rkUSDT
        rkUSDT.mint(owner, amount);
        
        emit DepositWithPermit2(owner, amount, sigDeadline);
        emit Deposit(owner, amount);
    }
    
    // Simple withdrawal request (for testnet)
    function requestWithdrawal(uint256 amount) public nonReentrant {
        if (amount == 0) revert ZeroAmount();
        
        // Burn rkUSDT
        rkUSDT.burn(msg.sender, amount);
        
        // Track withdrawal
        pendingWithdrawals[msg.sender] = amount;
        withdrawalEpoch[msg.sender] = currentEpoch();
        
        emit WithdrawalRequested(msg.sender, amount, currentEpoch());
    }
    
    function requestWithdraw(uint256 amount) external {
        requestWithdrawal(amount);
    }
    
    // Claim withdrawal (simplified for testnet)
    function claimWithdrawal() public nonReentrant {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No pending withdrawal");
        
        pendingWithdrawals[msg.sender] = 0;
        
        // Transfer USDT back
        require(USDT.transfer(msg.sender, amount), "Transfer failed");
        
        emit WithdrawalClaimed(msg.sender, amount);
    }
    
    function claim() external {
        claimWithdrawal();
    }
    
    // View functions for frontend
    function pendingWithdrawal(address user) external view returns (uint256 amount, uint64 epoch) {
        return (pendingWithdrawals[user], uint64(withdrawalEpoch[user]));
    }
    
    // Epoch view functions
    function currentEpoch() public view returns (uint64) {
        if (block.timestamp < epoch0Start) return 0;
        return uint64((block.timestamp - epoch0Start) / epochDuration);
    }
    
    function epochEnd(uint64 epoch) public view returns (uint64) {
        return epoch0Start + (epoch + 1) * epochDuration;
    }
    
    function timeUntilEpochEnd() public view returns (uint256) {
        uint64 end = epochEnd(currentEpoch());
        return end > block.timestamp ? end - block.timestamp : 0;
    }
    
    // Legacy compatibility
    function epochInfo() external view returns (uint64, uint64) {
        return (currentEpoch(), epochEnd(currentEpoch()));
    }
    
    function _u160(uint256 x) internal pure returns (uint160) {
        require(x <= type(uint160).max, "Overflow");
        return uint160(x);
    }
}