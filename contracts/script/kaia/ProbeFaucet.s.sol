// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";

interface IERC20Dec {
    function decimals() external view returns (uint8);
    function balanceOf(address) external view returns (uint256);
}

// Define interfaces for each faucet pattern
interface ITokenA { function mint(address to, uint256 amount) external; }
interface ITokenB { function mint(uint256 amount) external; }
interface ITokenC { function faucet() external; }
interface ITokenD { function drip() external; }
interface ITokenE { function claim() external; }
interface ITokenF { function freeMint(address to) external; }
interface ITokenG { function freeMint() external; }
interface ITokenH { function mintTo(address to, uint256 amount) external; }

/// @title Probe Faucet Functions
/// @notice Tests all possible faucet/mint function signatures on a token
/// @dev Use FAUCET_TOKEN env var for token address, FAUCET_TO for recipient (optional)
contract ProbeFaucet is Script {
    function run() external {
        address token = vm.envOr("FAUCET_TOKEN", address(0));
        require(token != address(0), "FAUCET_TOKEN not set");
        
        address who = vm.envOr("FAUCET_TO", address(0));
        
        console2.log("=== Probing Faucet Functions ===");
        console2.log("Token:", token);
        
        vm.startBroadcast();
        address me = who == address(0) ? tx.origin : who;
        console2.log("Recipient:", me);
        
        // Get decimals
        uint8 dec = 6;
        try IERC20Dec(token).decimals() returns (uint8 d) {
            dec = d;
            console2.log("Decimals:", dec);
        } catch {
            console2.log("Could not read decimals, assuming 6");
        }
        
        // Check initial balance
        uint256 pre = IERC20Dec(token).balanceOf(me);
        console2.log("Balance before:", pre);
        
        uint256 amt = 10_000 * (10 ** uint256(dec));
        console2.log("Test amount:", amt);
        console2.log("");
        
        // Try all faucet variants
        console2.log("Testing signatures:");
        bool success = false;
        string memory successMethod = "";
        
        // Try mint(address,uint256)
        if (!success) {
            (bool ok,) = _try(token, abi.encodeWithSelector(ITokenA.mint.selector, me, amt), "mint(address,uint256)");
            if (ok) { success = true; successMethod = "mint(address,uint256)"; }
        }
        
        // Try mint(uint256)
        if (!success) {
            (bool ok,) = _try(token, abi.encodeWithSelector(ITokenB.mint.selector, amt), "mint(uint256)");
            if (ok) { success = true; successMethod = "mint(uint256)"; }
        }
        
        // Try faucet()
        if (!success) {
            (bool ok,) = _try(token, abi.encodeWithSelector(ITokenC.faucet.selector), "faucet()");
            if (ok) { success = true; successMethod = "faucet()"; }
        }
        
        // Try drip()
        if (!success) {
            (bool ok,) = _try(token, abi.encodeWithSelector(ITokenD.drip.selector), "drip()");
            if (ok) { success = true; successMethod = "drip()"; }
        }
        
        // Try claim()
        if (!success) {
            (bool ok,) = _try(token, abi.encodeWithSelector(ITokenE.claim.selector), "claim()");
            if (ok) { success = true; successMethod = "claim()"; }
        }
        
        // Try freeMint(address)
        if (!success) {
            (bool ok,) = _try(token, abi.encodeWithSelector(ITokenF.freeMint.selector, me), "freeMint(address)");
            if (ok) { success = true; successMethod = "freeMint(address)"; }
        }
        
        // Try freeMint()
        if (!success) {
            (bool ok,) = _try(token, abi.encodeWithSelector(ITokenG.freeMint.selector), "freeMint()");
            if (ok) { success = true; successMethod = "freeMint()"; }
        }
        
        // Try mintTo(address,uint256)
        if (!success) {
            (bool ok,) = _try(token, abi.encodeWithSelector(ITokenH.mintTo.selector, me, amt), "mintTo(address,uint256)");
            if (ok) { success = true; successMethod = "mintTo(address,uint256)"; }
        }
        
        console2.log("");
        console2.log("=== Results ===");
        
        // Check final balance
        uint256 post = IERC20Dec(token).balanceOf(me);
        uint256 delta = post > pre ? post - pre : 0;
        
        console2.log("Balance after:", post);
        console2.log("Minted amount:", delta);
        
        if (success) {
            console2.log("Success! Working method:", successMethod);
        } else {
            console2.log("FAIL: No working faucet method found");
        }
        
        vm.stopBroadcast();
        
        // Exit with error if no method worked
        require(success, "No working faucet method found");
    }
    
    function _try(address to, bytes memory data, string memory tag) internal returns (bool ok, bytes memory ret) {
        (ok, ret) = to.call(data);
        if (ok) {
            console2.log("  [OK]", tag);
        } else {
            console2.log("  [FAIL]", tag);
            // Log revert reason if available
            if (ret.length > 0) {
                // Try to decode standard revert string
                if (ret.length >= 68) {
                    assembly {
                        ret := add(ret, 0x04)
                    }
                    string memory reason = abi.decode(ret, (string));
                    console2.log("    Reason:", reason);
                }
            }
        }
    }
}