// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {ReKaUSDVault} from "../src/ReKaUSDVault.sol";
import {rkUSDT} from "../src/rkUSDT.sol";
import {MockStargateAdapter} from "../src/MockStargateAdapter.sol";

contract MockUSDT is ERC20("MockUSDT", "USDT") {
    function decimals() public pure override returns (uint8) { return 6; }
    // emulate non-standard no-return transfer? OZ ERC20 returns bool; for vault we use SafeERC20 which handles both
}

contract ReKaUSDVaultTest is Test {
    MockUSDT usdt;
    rkUSDT rk;
    MockStargateAdapter adapter;
    ReKaUSDVault vault;
    address feeRecipient = address(0xFEE);
    address operator = address(0xBADD);
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    uint64 constant WEEK = 7 days;

    function setUp() public {
        usdt = new MockUSDT();
        rk = new rkUSDT();
        adapter = new MockStargateAdapter(address(usdt));
        vault = new ReKaUSDVault(address(usdt), address(rk), address(adapter), feeRecipient, WEEK);
        rk.transferOwnership(address(this));
        rk.setVault(address(vault));
        vault.transferOwnership(address(this));
        vault.setOperator(operator);

        // fund users
        deal(address(usdt), alice, 1_000_000e6);
        deal(address(usdt), bob, 1_000_000e6);

        vm.startPrank(alice);
        usdt.approve(address(vault), type(uint256).max);
        vm.stopPrank();
        vm.startPrank(bob);
        usdt.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function _rollover() internal {
        vm.prank(operator);
        vault.rolloverEpoch();
    }

    function test_DepositMints1to1() public {
        vm.prank(alice);
        vault.deposit(100e6);
        assertEq(rk.balanceOf(alice), 100e6);
    }

    function test_InstantWithdrawWithinSameEpoch() public {
        uint256 balBefore = usdt.balanceOf(alice);
        vm.prank(alice); vault.deposit(1_000e6);
        vm.prank(alice); vault.requestWithdraw(200e6);
        // 0.5% fee
        uint256 fee = 200e6 * 50 / 10_000;
        assertEq(usdt.balanceOf(feeRecipient), fee);
        assertEq(usdt.balanceOf(alice), balBefore - 1_000e6 + (200e6 - fee));
        assertEq(rk.balanceOf(alice), 800e6);
    }

    function test_QueuedWithdrawAcrossEpochs_ThenClaim() public {
        uint256 balBefore = usdt.balanceOf(alice);
        vm.prank(alice); vault.deposit(1_000e6);
        _rollover(); // move to next epoch, so instant window gone

        vm.prank(alice); vault.requestWithdraw(300e6);
        uint256 fee = 300e6 * 50 / 10_000;
        assertEq(usdt.balanceOf(feeRecipient), fee);
        // Not claimable yet
        vm.prank(alice);
        vm.expectRevert("nothing");
        vault.claim();

        // Next rollover makes queued claimable
        _rollover();
        // Now claim works
        vm.prank(alice); vault.claim();
        assertEq(usdt.balanceOf(alice), balBefore - 1_000e6 + (300e6 - fee));
    }

    function test_RolloverBridgingMath_ReservesForClaimables() public {
        // Alice deposits and queues withdrawal
        vm.prank(alice); vault.deposit(1_000e6);
        _rollover();
        vm.prank(alice); vault.requestWithdraw(400e6);
        uint256 fee = 400e6 * 50 / 10_000;
        assertEq(usdt.balanceOf(feeRecipient), fee);

        // Bob deposits after, to add more liquidity
        vm.prank(bob); vault.deposit(600e6);

        // At rollover: should reserve claimables including to-be-promoted pendingNext
        uint256 vaultBalBefore = usdt.balanceOf(address(vault));
        _rollover();
        uint256 expectedBridge = vaultBalBefore - (400e6 - fee);
        assertEq(adapter.lastBridgedAmount(), expectedBridge);

        // Now Alice can claim
        vm.prank(alice); vault.claim();
    }

    function test_Pause() public {
        vm.prank(address(this));
        vault.pause();
        vm.prank(alice);
        vm.expectRevert();
        vault.deposit(1);
        vm.prank(alice);
        vm.expectRevert();
        vault.requestWithdraw(1);
        vm.prank(address(this));
        vault.unpause();
        vm.prank(alice);
        vault.deposit(1);
    }

    function test_Auth() public {
        vm.prank(alice);
        vm.expectRevert(ReKaUSDVault.NotOperator.selector);
        vault.rolloverEpoch();

        vm.prank(address(this));
        vault.setOperator(operator);
    }

    function test_EdgeCases_ZeroAmounts() public {
        vm.prank(alice);
        vm.expectRevert(bytes("amount=0"));
        vault.deposit(0);

        vm.prank(alice);
        vm.expectRevert(bytes("amount=0"));
        vault.requestWithdraw(0);
    }
}
