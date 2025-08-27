// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {MockUSDTMintableOpen} from "../src/mocks/MockMintableERC20.sol";

contract Permit2BypassTest is Test {
    address constant PERMIT2 = address(0x2222);
    address constant ALICE = address(0xA11CE);
    address constant VAULT = address(0x7a017);
    address constant RANDOM_SPENDER = address(0xBEEF);
    
    MockUSDTMintableOpen usdt;
    
    function setUp() public {
        // Deploy mock USDT with Permit2 bypass enabled
        usdt = new MockUSDTMintableOpen("Test USDT", "USDT", PERMIT2);
        
        // Mint some tokens to Alice for testing
        usdt.mint(ALICE, 1000e6);
    }
    
    function test_permit2_can_transfer_without_allowance() public {
        uint256 aliceBalanceBefore = usdt.balanceOf(ALICE);
        uint256 vaultBalanceBefore = usdt.balanceOf(VAULT);
        
        // Simulate Permit2 calling transferFrom(alice -> vault) WITHOUT any allowance
        vm.prank(PERMIT2);
        bool success = usdt.transferFrom(ALICE, VAULT, 500e6);
        
        assertTrue(success, "Transfer should succeed");
        assertEq(usdt.balanceOf(ALICE), aliceBalanceBefore - 500e6, "Alice balance should decrease");
        assertEq(usdt.balanceOf(VAULT), vaultBalanceBefore + 500e6, "Vault balance should increase");
    }
    
    function test_permit2_can_transfer_full_balance() public {
        uint256 fullBalance = usdt.balanceOf(ALICE);
        
        // Permit2 should be able to transfer Alice's entire balance
        vm.prank(PERMIT2);
        bool success = usdt.transferFrom(ALICE, VAULT, fullBalance);
        
        assertTrue(success, "Transfer should succeed");
        assertEq(usdt.balanceOf(ALICE), 0, "Alice should have no balance left");
        assertEq(usdt.balanceOf(VAULT), fullBalance, "Vault should receive all tokens");
    }
    
    function test_non_permit2_still_requires_allowance() public {
        // Random spender tries to transfer without allowance - should fail
        vm.prank(RANDOM_SPENDER);
        vm.expectRevert("allow");
        usdt.transferFrom(ALICE, VAULT, 1);
    }
    
    function test_non_permit2_works_with_allowance() public {
        // Alice approves random spender
        vm.prank(ALICE);
        usdt.approve(RANDOM_SPENDER, 100e6);
        
        // Now random spender can transfer
        vm.prank(RANDOM_SPENDER);
        bool success = usdt.transferFrom(ALICE, VAULT, 100e6);
        
        assertTrue(success, "Transfer should succeed with allowance");
        assertEq(usdt.balanceOf(ALICE), 900e6, "Alice balance should decrease");
        assertEq(usdt.balanceOf(VAULT), 100e6, "Vault balance should increase");
        assertEq(usdt.allowance(ALICE, RANDOM_SPENDER), 0, "Allowance should be consumed");
    }
    
    function test_permit2_address_can_be_updated() public {
        address NEW_PERMIT2 = address(0x3333);
        
        // Only owner can update permit2 (test contract is the owner)
        vm.prank(address(0x1234)); // Non-owner address
        vm.expectRevert("owner");
        usdt.setPermit2(NEW_PERMIT2);
        
        // Owner updates permit2
        usdt.setPermit2(NEW_PERMIT2);
        assertEq(usdt.permit2(), NEW_PERMIT2, "Permit2 should be updated");
        
        // Old permit2 now requires allowance
        vm.prank(PERMIT2);
        vm.expectRevert("allow");
        usdt.transferFrom(ALICE, VAULT, 1);
        
        // New permit2 works without allowance
        vm.prank(NEW_PERMIT2);
        bool success = usdt.transferFrom(ALICE, VAULT, 100e6);
        assertTrue(success, "New permit2 should work");
    }
    
    function test_faucet_functions_still_work() public {
        address BOB = address(0xB0B);
        
        // Test mint(address, uint256)
        usdt.mint(BOB, 100e6);
        assertEq(usdt.balanceOf(BOB), 100e6, "mint(to, amount) should work");
        
        // Test mint(uint256) - mints to msg.sender
        vm.prank(BOB);
        usdt.mint(50e6);
        assertEq(usdt.balanceOf(BOB), 150e6, "mint(amount) should work");
        
        // Test faucet()
        vm.prank(BOB);
        usdt.faucet();
        assertEq(usdt.balanceOf(BOB), 150e6 + 10_000e6, "faucet() should mint 10k");
    }
}