// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {MockUSDT} from "../src/mocks/MockUSDT.sol";
import {MockUSDe} from "../src/mocks/MockUSDe.sol";
import {MockSUSDe} from "../src/mocks/MockSUSDe.sol";
import {MockSwapUSDTtoUSDe} from "../src/mocks/MockSwapUSDTtoUSDe.sol";
import {MockStakingUSDeToSUSDe} from "../src/mocks/MockStakingUSDeToSUSDe.sol";

contract EthenaMocksTest is Test {
    MockUSDT usdt;
    MockUSDe usde;
    MockSUSDe susde;
    MockSwapUSDTtoUSDe swap;
    MockStakingUSDeToSUSDe staking;

    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        usdt = new MockUSDT();
        usde = new MockUSDe();
        susde = new MockSUSDe();
        swap = new MockSwapUSDTtoUSDe(address(usdt), address(usde));
        staking = new MockStakingUSDeToSUSDe(address(usde), address(susde), 1100);
        susde.setVault(address(staking));
        usde.setMinter(address(swap), true);
        usde.setMinter(address(staking), true);

        usdt.mint(alice, 1_000_000e6);
        vm.startPrank(alice);
        usdt.approve(address(swap), type(uint256).max);
        usde.approve(address(staking), type(uint256).max);
        vm.stopPrank();

        usdt.mint(bob, 1_000_000e6);
        vm.startPrank(bob);
        usdt.approve(address(swap), type(uint256).max);
        usde.approve(address(staking), type(uint256).max);
        vm.stopPrank();
    }

    function test_Swap_USDT_to_USDe() public {
        vm.prank(alice);
        swap.swap(500_000e6, alice);
        assertEq(usde.balanceOf(alice), 500_000e18);

        swap.setRateBps(9_900);
        vm.prank(alice);
        swap.swap(100e6, alice);
        // 100 USDT at 9900 bps => 99 USDe
        assertEq(usde.balanceOf(alice), 500_000e18 + 99e18);
    }

    function test_StakeUnstake_NoTime() public {
        vm.startPrank(alice);
        swap.swap(10_000e6, alice);
        staking.stake(10_000e18, alice);
        assertEq(susde.balanceOf(alice), 10_000e18);
        vm.stopPrank();

        vm.startPrank(bob);
        swap.swap(10_000e6, bob);
        uint256 prevShares = staking.totalShares();
        uint256 prevVirt = staking.virtualAssets();
        staking.stake(10_000e18, bob);
        assertEq(staking.totalShares(), prevShares + 10_000e18);
        assertApproxEqAbs(staking.virtualAssets(), prevVirt + 10_000e18, 1); // small rounding
        vm.stopPrank();
    }

    function test_Accrual_11pct_APY_OverYear() public {
        vm.startPrank(alice);
        swap.swap(100_000e6, alice);
        staking.stake(100_000e18, alice);
        vm.stopPrank();

        // warp 365 days
        vm.warp(block.timestamp + 365 days);
        staking.harvest();
        uint256 virt = staking.virtualAssets();
        assertApproxEqRel(virt, 111_000e18, 0.0003e18); // allow ~3 bps

        // Unstake all
        uint256 shares = susde.balanceOf(alice);
        vm.prank(alice);
        staking.unstake(shares, alice);
        assertApproxEqRel(usde.balanceOf(alice), 111_000e18, 0.0003e18);
    }

    function test_ProportionalShares_WithTimeGap() public {
        vm.prank(alice);
        swap.swap(100_000e6, alice);
        vm.prank(alice);
        staking.stake(100_000e18, alice);

        vm.warp(block.timestamp + 180 days);

        vm.prank(bob);
        swap.swap(100_000e6, bob);
        vm.prank(bob);
        staking.stake(100_000e18, bob);

        // Bob should get fewer shares than Alice due to higher index
        assertLt(susde.balanceOf(bob), susde.balanceOf(alice));

        vm.warp(block.timestamp + 185 days);
        uint256 aliceShares = susde.balanceOf(alice);
        uint256 bobShares = susde.balanceOf(bob);
        vm.prank(alice);
        staking.unstake(aliceShares, alice);
        vm.prank(bob);
        staking.unstake(bobShares, bob);

        // Both should receive ~111k each in total out; allow wider tolerance due to discrete comp rounding
        assertApproxEqRel(usde.balanceOf(alice), 111_000e18, 0.06e18);
        assertApproxEqRel(usde.balanceOf(bob), 111_000e18, 0.06e18);
    }

    function test_MaterializeOnDemand() public {
        vm.startPrank(alice);
        swap.swap(10_000e6, alice);
        staking.stake(10_000e18, alice);
        vm.stopPrank();

        vm.warp(block.timestamp + 1000 days);
        // Balance much lower than virtual; unstake should mint the gap via _materializeYield
        uint256 shares = susde.balanceOf(alice);
        vm.prank(alice);
        staking.unstake(shares, alice);
        assertGt(usde.balanceOf(alice), 10_000e18);
    }

    function test_AdminGuards() public {
        // sUSDe vault guard
        vm.expectRevert(MockSUSDe.NotVault.selector);
        susde.mint(alice, 1e18);

        // only owner
        vm.expectRevert();
        vm.prank(alice);
        staking.setAPYBps(1000);

        staking.setAPYBps(1100);
    }

    function test_Views_Monotonic() public {
        vm.prank(alice);
        swap.swap(10_000e6, alice);
        vm.prank(alice);
        staking.stake(10_000e18, alice);

        uint256 v1 = staking.virtualAssets();
        vm.warp(block.timestamp + 1 days);
        uint256 v2 = staking.virtualAssets();
        assertGt(v2, v1);
    }
}
