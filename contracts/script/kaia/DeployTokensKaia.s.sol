// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {MockUSDTMintableOpen, MockRKUSDTMintable} from "../../src/mocks/MockMintableERC20.sol";

contract DeployTokensKaia is Script {
    function run() external {
        // Check if tokens already exist via env
        address usdt = vm.envOr("KAIA_USDT", address(0));
        address rkusdt = vm.envOr("KAIA_RKUSDT", address(0));
        
        vm.startBroadcast();
        
        // Deploy USDT if not provided
        if (usdt == address(0)) {
            MockUSDTMintableOpen usdtContract = new MockUSDTMintableOpen("Tether USD", "USDT");
            usdt = address(usdtContract);
            console2.log("Deployed new USDT:", usdt);
        } else {
            console2.log("Using existing USDT:", usdt);
        }
        
        // Deploy rkUSDT if not provided
        if (rkusdt == address(0)) {
            MockRKUSDTMintable rkusdtContract = new MockRKUSDTMintable("ReKaUSD Receipt", "rkUSDT");
            rkusdt = address(rkusdtContract);
            console2.log("Deployed new rkUSDT:", rkusdt);
        } else {
            console2.log("Using existing rkUSDT:", rkusdt);
        }
        
        vm.stopBroadcast();
        
        console2.log("=== Token Deployment Complete ===");
        console2.log("USDT:", usdt);
        console2.log("rkUSDT:", rkusdt);
    }
}