// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {rkUSDT} from "../src/rkUSDT.sol";

contract RKTokenTest is Test {
    rkUSDT rk;
    address vault = address(0xBEEF);
    address user = address(0x1234);

    function setUp() public {
        rk = new rkUSDT();
        rk.transferOwnership(address(this));
        rk.setVault(vault);
    }

    function test_Metadata() public {
        assertEq(rk.name(), "ReKaUSD Restaked USDT");
        assertEq(rk.symbol(), "rkUSDT");
        assertEq(rk.decimals(), 6);
    }

    function test_OnlyVaultCanMintBurn() public {
        vm.expectRevert(rkUSDT.NotVault.selector);
        rk.mint(user, 1);

        vm.prank(vault);
        rk.mint(user, 100);
        assertEq(rk.balanceOf(user), 100);

        vm.expectRevert(rkUSDT.NotVault.selector);
        rk.burn(user, 100);

        vm.prank(vault);
        rk.burn(user, 100);
        assertEq(rk.balanceOf(user), 0);
    }
}
