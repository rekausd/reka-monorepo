// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import {EpochEthenaStrategyUUPSSimple} from "../../src/eth/strategy/EpochEthenaStrategyUUPSSimple.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract DeployStrategyUUPS is Script {
    struct DeployParams {
        address operator;
        address guardian;
        address multisig;
        uint256 minDelay;
        address usdt;
        address usde;
        address susde;
        address swapAdapter;
        address stakingAdapter;
        address bridgeAdapter;
        uint16 kaiaChainId;
        address kaiaRecipient;
        uint256 slippageBps;
    }

    function run() external {
        uint256 deployerKey = vm.envUint("DEPLOYER_PK");
        address deployer = vm.addr(deployerKey);
        
        DeployParams memory params = DeployParams({
            operator: vm.envAddress("OPERATOR"),
            guardian: vm.envAddress("GUARDIAN"),
            multisig: vm.envAddress("MULTISIG"),
            minDelay: vm.envOr("TIMELOCK_DELAY", uint256(24 * 3600)),
            usdt: vm.envAddress("USDT_ADDRESS"),
            usde: vm.envAddress("USDE_ADDRESS"),
            susde: vm.envAddress("SUSDE_ADDRESS"),
            swapAdapter: vm.envAddress("SWAP_ADAPTER"),
            stakingAdapter: vm.envAddress("STAKING_ADAPTER"),
            bridgeAdapter: vm.envAddress("BRIDGE_ADAPTER"),
            kaiaChainId: uint16(vm.envUint("KAIA_CHAIN_ID")),
            kaiaRecipient: vm.envAddress("KAIA_RECIPIENT"),
            slippageBps: vm.envOr("SLIPPAGE_BPS", uint256(50))
        });
        
        vm.startBroadcast(deployerKey);
        
        // 1. Deploy implementation
        EpochEthenaStrategyUUPSSimple implementation = new EpochEthenaStrategyUUPSSimple();
        console2.log("Implementation deployed:", address(implementation));
        
        // 2. Prepare initializer data
        bytes memory initData = abi.encodeWithSelector(
            EpochEthenaStrategyUUPSSimple.initialize.selector,
            deployer,  // temp owner (will transfer to timelock)
            params.operator,
            params.guardian,
            params.usdt,
            params.usde,
            params.susde,
            params.swapAdapter,
            params.stakingAdapter,
            params.bridgeAdapter,
            params.kaiaChainId,
            params.kaiaRecipient,
            params.slippageBps
        );
        
        // 3. Deploy proxy with initialization
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        console2.log("Proxy deployed:", address(proxy));
        
        // 4. Cast proxy to strategy interface
        EpochEthenaStrategyUUPSSimple strategy = EpochEthenaStrategyUUPSSimple(address(proxy));
        
        // 5. Deploy TimelockController
        address[] memory proposers = new address[](1);
        proposers[0] = params.multisig;
        
        address[] memory executors = new address[](1);
        executors[0] = params.multisig;
        
        TimelockController timelock = new TimelockController(
            params.minDelay,
            proposers,
            executors,
            deployer // admin (will renounce after setup)
        );
        console2.log("Timelock deployed:", address(timelock));
        
        // 6. Transfer strategy ownership to timelock
        strategy.transferOwnership(address(timelock));
        console2.log("Strategy ownership transferred to timelock");
        
        // 7. Renounce timelock admin role (optional - do this after verification)
        // timelock.renounceRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);
        
        vm.stopBroadcast();
        
        // Log deployment summary
        console2.log("=====================================");
        console2.log("Deployment Summary:");
        console2.log("=====================================");
        console2.log("Implementation:", address(implementation));
        console2.log("Proxy (Strategy):", address(proxy));
        console2.log("Timelock:", address(timelock));
        console2.log("Operator:", params.operator);
        console2.log("Guardian:", params.guardian);
        console2.log("Multisig:", params.multisig);
        console2.log("Min Delay:", params.minDelay, "seconds");
        console2.log("=====================================");
        
        // Write deployment addresses to file for reference
        string memory deploymentInfo = string(abi.encodePacked(
            "STRATEGY_IMPL=", vm.toString(address(implementation)), "\n",
            "STRATEGY_PROXY=", vm.toString(address(proxy)), "\n",
            "TIMELOCK=", vm.toString(address(timelock)), "\n"
        ));
        
        vm.writeFile("./deployments/strategy-uups.txt", deploymentInfo);
    }
}