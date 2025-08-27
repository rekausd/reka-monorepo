// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {SimpleRekaUSDVault} from "../../src/kaia/SimpleRekaUSDVault.sol";
import {MockUSDTMintableOpen, MockRKUSDTMintable} from "../../src/mocks/MockMintableERC20.sol";
import {IPermit2} from "../../src/common/permit2/IPermit2.sol";

contract SimpleRekaUSDVaultEpochTest is Test {
    SimpleRekaUSDVault public vault;
    MockUSDTMintableOpen public usdt;
    MockRKUSDTMintable public rkusdt;
    address public permit2 = address(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    
    function setUp() public {
        // Deploy mocks
        usdt = new MockUSDTMintableOpen("USDT", "USDT", permit2);
        rkusdt = new MockRKUSDTMintable("rkUSDT", "rkUSDT");
        
        // Deploy vault at a specific timestamp for testing
        // Set to a known UTC midnight for predictable testing
        uint256 deployTime = 1704067200; // January 1, 2024, 00:00 UTC
        vm.warp(deployTime + 12 hours); // Deploy at noon UTC
        
        vault = new SimpleRekaUSDVault(address(usdt), address(rkusdt), permit2);
        
        // Set vault as minter for rkUSDT
        rkusdt.setMinter(address(vault));
        
        // Setup test accounts
        usdt.mint(alice, 1000e6);
        usdt.mint(bob, 1000e6);
        
        vm.prank(alice);
        usdt.approve(address(vault), type(uint256).max);
        vm.prank(bob);
        usdt.approve(address(vault), type(uint256).max);
    }
    
    function testEpochDuration() public {
        assertEq(vault.epochDuration(), 10 days, "Epoch duration should be 10 days");
        assertEq(vault.epochDuration(), 864000, "Epoch duration should be 864000 seconds");
    }
    
    function testEpoch0StartAlignment() public {
        // epoch0Start should be aligned to UTC midnight of deployment day
        uint64 epoch0 = vault.epoch0Start();
        
        // Should be January 1, 2024, 00:00 UTC
        assertEq(epoch0, 1704067200, "Epoch 0 should start at UTC midnight");
        
        // Verify it's aligned to day boundary
        assertEq(epoch0 % 1 days, 0, "Epoch 0 start should be aligned to day boundary");
    }
    
    function testCurrentEpoch() public {
        // At deployment time (noon of day 0), should be epoch 0
        assertEq(vault.currentEpoch(), 0, "Should be epoch 0 at deployment");
        
        // Jump to day 9 (still epoch 0)
        vm.warp(vault.epoch0Start() + 9 days);
        assertEq(vault.currentEpoch(), 0, "Should still be epoch 0 at day 9");
        
        // Jump to day 10 (epoch 1)
        vm.warp(vault.epoch0Start() + 10 days);
        assertEq(vault.currentEpoch(), 1, "Should be epoch 1 at day 10");
        
        // Jump to day 20 (epoch 2)
        vm.warp(vault.epoch0Start() + 20 days);
        assertEq(vault.currentEpoch(), 2, "Should be epoch 2 at day 20");
        
        // Jump to day 25 (still epoch 2)
        vm.warp(vault.epoch0Start() + 25 days);
        assertEq(vault.currentEpoch(), 2, "Should still be epoch 2 at day 25");
    }
    
    function testEpochEnd() public {
        uint64 epoch0Start = vault.epoch0Start();
        
        // Epoch 0 ends at start + 10 days
        assertEq(vault.epochEnd(0), epoch0Start + 10 days, "Epoch 0 should end after 10 days");
        
        // Epoch 1 ends at start + 20 days
        assertEq(vault.epochEnd(1), epoch0Start + 20 days, "Epoch 1 should end after 20 days");
        
        // Epoch 5 ends at start + 60 days
        assertEq(vault.epochEnd(5), epoch0Start + 60 days, "Epoch 5 should end after 60 days");
    }
    
    function testTimeUntilEpochEnd() public {
        uint64 epoch0Start = vault.epoch0Start();
        
        // At start of epoch 0
        vm.warp(epoch0Start);
        assertEq(vault.timeUntilEpochEnd(), 10 days, "Should be 10 days until epoch end");
        
        // Halfway through epoch 0
        vm.warp(epoch0Start + 5 days);
        assertEq(vault.timeUntilEpochEnd(), 5 days, "Should be 5 days until epoch end");
        
        // One second before epoch 1
        vm.warp(epoch0Start + 10 days - 1);
        assertEq(vault.timeUntilEpochEnd(), 1, "Should be 1 second until epoch end");
        
        // Start of epoch 1
        vm.warp(epoch0Start + 10 days);
        assertEq(vault.timeUntilEpochEnd(), 10 days, "Should be 10 days until next epoch end");
    }
    
    function testEpochInfo() public {
        uint64 epoch0Start = vault.epoch0Start();
        
        // At start of epoch 0
        vm.warp(epoch0Start);
        (uint64 currentEp, uint64 epochEndTime) = vault.epochInfo();
        assertEq(currentEp, 0, "Should be epoch 0");
        assertEq(epochEndTime, epoch0Start + 10 days, "Epoch 0 should end at correct time");
        
        // During epoch 2
        vm.warp(epoch0Start + 25 days);
        (currentEp, epochEndTime) = vault.epochInfo();
        assertEq(currentEp, 2, "Should be epoch 2");
        assertEq(epochEndTime, epoch0Start + 30 days, "Epoch 2 should end at correct time");
    }
    
    function testWithdrawalEpochTracking() public {
        // Alice deposits and requests withdrawal in epoch 0
        vm.prank(alice);
        vault.deposit(100e6);
        
        vm.prank(alice);
        vault.requestWithdrawal(50e6);
        
        // Check withdrawal is recorded with correct epoch
        (uint256 amount, uint64 epoch) = vault.pendingWithdrawal(alice);
        assertEq(amount, 50e6, "Withdrawal amount should be recorded");
        assertEq(epoch, 0, "Withdrawal should be in epoch 0");
        
        // Move to epoch 1 and bob requests withdrawal
        vm.warp(vault.epoch0Start() + 11 days);
        
        vm.prank(bob);
        vault.deposit(200e6);
        
        vm.prank(bob);
        vault.requestWithdrawal(100e6);
        
        (amount, epoch) = vault.pendingWithdrawal(bob);
        assertEq(amount, 100e6, "Bob's withdrawal amount should be recorded");
        assertEq(epoch, 1, "Bob's withdrawal should be in epoch 1");
        
        // Alice's withdrawal epoch should remain unchanged
        (amount, epoch) = vault.pendingWithdrawal(alice);
        assertEq(epoch, 0, "Alice's withdrawal should still be in epoch 0");
    }
    
    function testEpochBoundaryConditions() public {
        uint64 epoch0Start = vault.epoch0Start();
        
        // Exactly at epoch boundary
        vm.warp(epoch0Start + 10 days);
        assertEq(vault.currentEpoch(), 1, "Should be epoch 1 exactly at boundary");
        assertEq(vault.timeUntilEpochEnd(), 10 days, "Should have full epoch duration remaining");
        
        // One second before boundary
        vm.warp(epoch0Start + 10 days - 1);
        assertEq(vault.currentEpoch(), 0, "Should still be epoch 0 one second before boundary");
        assertEq(vault.timeUntilEpochEnd(), 1, "Should have 1 second remaining");
        
        // One second after boundary
        vm.warp(epoch0Start + 10 days + 1);
        assertEq(vault.currentEpoch(), 1, "Should be epoch 1 one second after boundary");
        assertEq(vault.timeUntilEpochEnd(), 10 days - 1, "Should have almost full epoch remaining");
    }
    
    function testFuzzEpochCalculations(uint256 timeOffset) public {
        // Bound time offset to reasonable range (0 to 100 epochs)
        timeOffset = bound(timeOffset, 0, 1000 days);
        
        uint64 epoch0Start = vault.epoch0Start();
        vm.warp(epoch0Start + timeOffset);
        
        uint64 expectedEpoch = uint64(timeOffset / 10 days);
        assertEq(vault.currentEpoch(), expectedEpoch, "Epoch calculation should be correct");
        
        uint64 expectedEpochEnd = epoch0Start + (expectedEpoch + 1) * 10 days;
        assertEq(vault.epochEnd(expectedEpoch), expectedEpochEnd, "Epoch end calculation should be correct");
        
        uint256 expectedTimeRemaining = expectedEpochEnd > block.timestamp ? 
            expectedEpochEnd - block.timestamp : 0;
        assertEq(vault.timeUntilEpochEnd(), expectedTimeRemaining, "Time until epoch end should be correct");
    }
}