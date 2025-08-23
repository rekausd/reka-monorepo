// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {rkUSDT} from "reka-kaia/rkUSDT.sol";
import {MockStargateAdapter} from "reka-kaia/MockStargateAdapter.sol";
import {ReKaUSDVault} from "reka-kaia/ReKaUSDVault.sol";

contract Deploy is Script {
    function run() external {
        address usdt = vm.envAddress("USDT_ADDR");
        address feeRecipient = vm.envAddress("FEE_RECIPIENT");
        uint64 epochDuration = uint64(vm.envOr("EPOCH_DURATION", uint256(7 days)));

        vm.startBroadcast();
        rkUSDT rk = new rkUSDT();
        MockStargateAdapter adapter = new MockStargateAdapter(usdt);
        ReKaUSDVault vault = new ReKaUSDVault(address(usdt), address(rk), address(adapter), feeRecipient, epochDuration);
        rk.transferOwnership(msg.sender);
        rk.setVault(address(vault));
        vault.transferOwnership(msg.sender);
        vault.setOperator(msg.sender);
        vm.stopBroadcast();

        console2.log("rkUSDT:", address(rk));
        console2.log("Adapter:", address(adapter));
        console2.log("Vault:", address(vault));
    }
}
