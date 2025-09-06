// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {EpochEthenaStrategyUUPSSimple} from "../../src/eth/strategy/EpochEthenaStrategyUUPSSimple.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract GovernanceOps is Script {
    TimelockController public timelock;
    EpochEthenaStrategyUUPSSimple public strategy;
    
    // Schedule an upgrade through timelock
    function scheduleUpgrade(address newImplementation) external {
        address timelockAddr = vm.envAddress("TIMELOCK_ADDRESS");
        address strategyProxy = vm.envAddress("STRATEGY_PROXY");
        uint256 signerKey = vm.envUint("MULTISIG_SIGNER_PK");
        
        timelock = TimelockController(payable(timelockAddr));
        strategy = EpochEthenaStrategyUUPSSimple(strategyProxy);
        
        // Prepare upgrade call
        bytes memory upgradeCall = abi.encodeWithSelector(
            EpochEthenaStrategyUUPSSimple.upgradeToAndCall.selector,
            newImplementation,
            bytes("")
        );
        
        // Calculate operation ID
        bytes32 operationId = timelock.hashOperation(
            strategyProxy,
            0,
            upgradeCall,
            bytes32(0),
            bytes32(block.timestamp) // salt for uniqueness
        );
        
        vm.startBroadcast(signerKey);
        
        // Schedule the upgrade
        timelock.schedule(
            strategyProxy,
            0,
            upgradeCall,
            bytes32(0),
            bytes32(block.timestamp),
            timelock.getMinDelay()
        );
        
        vm.stopBroadcast();
        
        console2.log("Upgrade scheduled with ID:", vm.toString(operationId));
        console2.log("Execute after:", block.timestamp + timelock.getMinDelay());
    }
    
    // Execute a scheduled upgrade
    function executeUpgrade(bytes32 operationId) external {
        address timelockAddr = vm.envAddress("TIMELOCK_ADDRESS");
        address strategyProxy = vm.envAddress("STRATEGY_PROXY");
        address newImplementation = vm.envAddress("NEW_IMPLEMENTATION");
        uint256 signerKey = vm.envUint("MULTISIG_SIGNER_PK");
        
        timelock = TimelockController(payable(timelockAddr));
        
        bytes memory upgradeCall = abi.encodeWithSelector(
            EpochEthenaStrategyUUPSSimple.upgradeToAndCall.selector,
            newImplementation,
            bytes("")
        );
        
        vm.startBroadcast(signerKey);
        
        // Execute the upgrade
        timelock.execute(
            strategyProxy,
            0,
            upgradeCall,
            bytes32(0),
            bytes32(0) // Must match the salt used in schedule
        );
        
        vm.stopBroadcast();
        
        console2.log("Upgrade executed successfully");
        console2.log("New implementation:", newImplementation);
    }
    
    // Schedule a parameter change
    function scheduleParamChange(
        string calldata functionSig,
        bytes calldata params
    ) external {
        address timelockAddr = vm.envAddress("TIMELOCK_ADDRESS");
        address strategyProxy = vm.envAddress("STRATEGY_PROXY");
        uint256 signerKey = vm.envUint("MULTISIG_SIGNER_PK");
        
        timelock = TimelockController(payable(timelockAddr));
        
        // Encode the function call
        bytes memory callData = abi.encodePacked(
            bytes4(keccak256(bytes(functionSig))),
            params
        );
        
        bytes32 operationId = timelock.hashOperation(
            strategyProxy,
            0,
            callData,
            bytes32(0),
            bytes32(block.timestamp)
        );
        
        vm.startBroadcast(signerKey);
        
        timelock.schedule(
            strategyProxy,
            0,
            callData,
            bytes32(0),
            bytes32(block.timestamp),
            timelock.getMinDelay()
        );
        
        vm.stopBroadcast();
        
        console2.log("Parameter change scheduled with ID:", vm.toString(operationId));
        console2.log("Function:", functionSig);
    }
    
    // Emergency pause (direct call by guardian)
    function emergencyPause() external {
        address strategyProxy = vm.envAddress("STRATEGY_PROXY");
        uint256 guardianKey = vm.envUint("GUARDIAN_PK");
        
        strategy = EpochEthenaStrategyUUPSSimple(strategyProxy);
        
        vm.startBroadcast(guardianKey);
        strategy.pause();
        vm.stopBroadcast();
        
        console2.log("Strategy paused by guardian");
    }
    
    // Schedule unpause through governance
    function scheduleUnpause() external {
        address timelockAddr = vm.envAddress("TIMELOCK_ADDRESS");
        address strategyProxy = vm.envAddress("STRATEGY_PROXY");
        uint256 signerKey = vm.envUint("MULTISIG_SIGNER_PK");
        
        timelock = TimelockController(payable(timelockAddr));
        
        bytes memory unpauseCall = abi.encodeWithSelector(
            EpochEthenaStrategyUUPSSimple.unpause.selector
        );
        
        bytes32 operationId = timelock.hashOperation(
            strategyProxy,
            0,
            unpauseCall,
            bytes32(0),
            bytes32(block.timestamp)
        );
        
        vm.startBroadcast(signerKey);
        
        timelock.schedule(
            strategyProxy,
            0,
            unpauseCall,
            bytes32(0),
            bytes32(block.timestamp),
            timelock.getMinDelay()
        );
        
        vm.stopBroadcast();
        
        console2.log("Unpause scheduled with ID:", vm.toString(operationId));
    }
}