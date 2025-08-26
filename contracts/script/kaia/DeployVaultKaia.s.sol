// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {SimpleRekaUSDVault} from "../../src/kaia/SimpleRekaUSDVault.sol";

contract DeployVaultKaia is Script {
    function run() external {
        // Read addresses from environment
        address usdt = vm.envAddress("KAIA_USDT");
        address rkusdt = vm.envAddress("KAIA_RKUSDT");
        address permit2 = vm.envAddress("KAIA_PERMIT2");
        
        console2.log("=== Deploying Vault ===");
        console2.log("USDT:", usdt);
        console2.log("rkUSDT:", rkusdt);
        console2.log("Permit2:", permit2);
        
        vm.startBroadcast();
        
        // Deploy vault
        SimpleRekaUSDVault vault = new SimpleRekaUSDVault(usdt, rkusdt, permit2);
        console2.log("Vault deployed:", address(vault));
        
        // Try to set rkUSDT minter to vault (only if mock supports)
        (bool ok, ) = rkusdt.call(abi.encodeWithSignature("setMinter(address)", address(vault)));
        if (ok) {
            console2.log("[OK] rkUSDT minter set to Vault");
        } else {
            console2.log("[WARN] Could not set rkUSDT minter (may not be owner)");
        }
        
        vm.stopBroadcast();
        
        console2.log("=== Vault Deployment Complete ===");
        console2.log("Vault Address:", address(vault));
    }
}