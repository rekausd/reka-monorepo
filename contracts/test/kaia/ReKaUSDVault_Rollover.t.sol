// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {ReKaUSDVault} from "reka-kaia/ReKaUSDVault.sol";
import {rkUSDT} from "reka-kaia/rkUSDT.sol";
import {MockStargateAdapter} from "reka-kaia/MockStargateAdapter.sol";

contract MockUSDT is ERC20("MockUSDT", "USDT") {
    function decimals() public pure override returns (uint8) { return 6; }
}

contract ReKaUSDVaultRolloverTest is Test {
    MockUSDT usdt;
    rkUSDT rk;
    MockStargateAdapter adapter;
    ReKaUSDVault vault;
    address feeRecipient = address(0xFEE);
    address operator = address(0xBADD);
    address alice = address(0xA11CE);

    uint256 constant WEEK = 7 days;

    function setUp() public {
        usdt = new MockUSDT();
        rk = new rkUSDT();
        adapter = new MockStargateAdapter(address(usdt));
        vault = new ReKaUSDVault(address(usdt), address(rk), address(adapter), feeRecipient, 7 days);
        rk.transferOwnership(address(this));
        rk.setVault(address(vault));
        vault.transferOwnership(address(this));
        vault.setOperator(operator);

        deal(address(usdt), alice, 1_000_000e6);
        vm.startPrank(alice);
        usdt.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function test_NotDueYet_RevertsUntilWeekBoundary() public {
        vm.prank(operator);
        vm.expectRevert(ReKaUSDVault.RolloverNotDue.selector);
        vault.rolloverEpoch();

        vm.warp(block.timestamp + WEEK - 1);
        vm.prank(operator);
        vm.expectRevert(ReKaUSDVault.RolloverNotDue.selector);
        vault.rolloverEpoch();

        vm.warp(block.timestamp + 1);
        vm.prank(operator);
        vault.rolloverEpoch();
        assertEq(vault.currentEpoch(), 1);
        assertEq(vault.nextWindow(), uint64(block.timestamp + WEEK));
    }

    function test_DuplicateInSameWeekBlocked() public {
        vm.warp(block.timestamp + WEEK);
        vm.prank(operator);
        vault.rolloverEpoch();
        vm.prank(operator);
        vm.expectRevert(ReKaUSDVault.RolloverNotDue.selector);
        vault.rolloverEpoch();
    }

    function test_CatchUpOverMultipleWeeks() public {
        uint64 start = vault.epochStart();
        vm.warp(start + 4 * WEEK);
        vm.prank(operator); vault.rolloverEpoch();
        vm.prank(operator); vault.rolloverEpoch();
        vm.prank(operator); vault.rolloverEpoch();
        assertEq(vault.currentEpoch(), 3);
        assertEq(vault.nextWindow(), uint64(start + 4 * WEEK));
    }

    function test_AccountingPreservedAtRollover() public {
        // Alice deposits epoch 0
        vm.prank(alice); vault.deposit(1_000e6);
        // Queue withdrawal after rollover
        vm.warp(block.timestamp + WEEK);
        vm.prank(operator); vault.rolloverEpoch();

        // Now request withdraw -> queued for next epoch
        vm.prank(alice); vault.requestWithdraw(400e6);
        uint256 fee = 400e6 * 50 / 10_000;
        // Bob deposits to add liquidity
        address bob = address(0xB0B);
        deal(address(usdt), bob, 1_000_000e6);
        vm.prank(bob); usdt.approve(address(vault), type(uint256).max);
        vm.prank(bob); vault.deposit(600e6);

        // Next week rollover
        vm.warp(block.timestamp + WEEK);
        uint256 vaultBalBefore = usdt.balanceOf(address(vault));
        vm.prank(operator); vault.rolloverEpoch();
        uint256 expectedBridge = vaultBalBefore - (400e6 - fee);
        assertEq(adapter.lastBridgedAmount(), expectedBridge);

        // Claim works
        vm.prank(alice); vault.claim();
        assertEq(usdt.balanceOf(alice), 1_000_000e6 - 1_000e6 + (400e6 - fee));
    }

    function test_AuthAndPauseGuards() public {
        vm.expectRevert(ReKaUSDVault.NotOperator.selector);
        vault.rolloverEpoch();

        vm.prank(address(this));
        vault.pause();
        vm.warp(block.timestamp + WEEK);
        vm.prank(operator);
        vm.expectRevert();
        vault.rolloverEpoch();

        vm.prank(address(this));
        vault.unpause();
        vm.prank(operator);
        vault.rolloverEpoch();
    }
}
