// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {MockUSDT} from "reka-mocks/MockUSDT.sol";
import {MockUSDe} from "reka-mocks/MockUSDe.sol";
import {MockSUSDe} from "reka-mocks/MockSUSDe.sol";
import {MockSwapUSDTtoUSDe} from "reka-mocks/MockSwapUSDTtoUSDe.sol";
import {MockStakingUSDeToSUSDe} from "reka-mocks/MockStakingUSDeToSUSDe.sol";

contract DeployMocks is Script {
    function run() external {
        vm.startBroadcast();
        MockUSDT usdt = new MockUSDT();
        MockUSDe usde = new MockUSDe();
        MockSUSDe susde = new MockSUSDe();

        MockSwapUSDTtoUSDe swap = new MockSwapUSDTtoUSDe(address(usdt), address(usde));
        MockStakingUSDeToSUSDe staking = new MockStakingUSDeToSUSDe(address(usde), address(susde), 1100);
        susde.setVault(address(staking));
        usde.setMinter(address(swap), true);
        usde.setMinter(address(staking), true);

        usdt.mint(msg.sender, 1_000_000e6);
        usde.mint(msg.sender, 1_000_000e18);
        vm.stopBroadcast();

        console2.log("USDT:", address(usdt));
        console2.log("USDe:", address(usde));
        console2.log("sUSDe:", address(susde));
        console2.log("Swap:", address(swap));
        console2.log("Staking:", address(staking));
    }
}
