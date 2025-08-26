// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {MockUSDTMintableOpen, MockRKUSDTMintable} from "../../src/mocks/MockMintableERC20.sol";
import {SimpleRekaUSDVault} from "../../src/kaia/SimpleRekaUSDVault.sol";

/// @title Deploy all KAIA contracts in one transaction
/// @notice Deploys USDT, rkUSDT, and Vault for KAIA testnet
contract DeployAllKaia is Script {
    function run() external returns (address usdt, address rkusdt, address vault) {
        // Read Permit2 from env or use default
        address permit2 = vm.envOr("KAIA_PERMIT2", address(0x000000000022D473030F116dDEE9F6B43aC78BA3));
        
        // Check if contracts already exist (to avoid redeploying)
        address existingUsdt = vm.envOr("KAIA_USDT", address(0));
        address existingRkusdt = vm.envOr("KAIA_RKUSDT", address(0));
        address existingVault = vm.envOr("KAIA_VAULT", address(0));
        
        console2.log("=== KAIA All-in-One Deployment ===");
        console2.log("Permit2:", permit2);
        
        vm.startBroadcast();
        
        // Deploy or use existing USDT
        if (existingUsdt != address(0)) {
            usdt = existingUsdt;
            console2.log("Using existing USDT:", usdt);
        } else {
            MockUSDTMintableOpen usdtContract = new MockUSDTMintableOpen("Tether USD", "USDT");
            usdt = address(usdtContract);
            console2.log("Deployed new USDT:", usdt);
        }
        
        // Deploy or use existing rkUSDT
        if (existingRkusdt != address(0)) {
            rkusdt = existingRkusdt;
            console2.log("Using existing rkUSDT:", rkusdt);
        } else {
            MockRKUSDTMintable rkusdtContract = new MockRKUSDTMintable("ReKaUSD Receipt", "rkUSDT");
            rkusdt = address(rkusdtContract);
            console2.log("Deployed new rkUSDT:", rkusdt);
        }
        
        // Deploy or use existing Vault
        if (existingVault != address(0)) {
            vault = existingVault;
            console2.log("Using existing Vault:", vault);
        } else {
            SimpleRekaUSDVault vaultContract = new SimpleRekaUSDVault(usdt, rkusdt, permit2);
            vault = address(vaultContract);
            console2.log("Deployed new Vault:", vault);
            
            // Try to set minter on rkUSDT (only if we own it)
            (bool ok, ) = rkusdt.call(abi.encodeWithSignature("setMinter(address)", vault));
            if (ok) {
                console2.log("[OK] rkUSDT minter set to Vault");
            } else {
                console2.log("[WARN] Could not set rkUSDT minter (may already be set)");
            }
        }
        
        vm.stopBroadcast();
        
        console2.log("=== Deployment Complete ===");
        console2.log("USDT:", usdt);
        console2.log("rkUSDT:", rkusdt);
        console2.log("Vault:", vault);
        console2.log("Permit2:", permit2);
        
        return (usdt, rkusdt, vault);
    }
}