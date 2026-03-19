// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {console2} from "forge-std/Script.sol";

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";

import {BaseScript} from "./base/BaseScript.sol";
import {ChainLocalizedRoutingHook} from "src/ChainLocalizedRoutingHook.sol";
import {RoutingPolicyRegistry} from "src/RoutingPolicyRegistry.sol";

/// @notice Mines the address and deploys the ChainLocalizedRoutingHook and RoutingPolicyRegistry contracts.
contract DeployHookScript is BaseScript {
    function run() public {
        vm.startBroadcast();
        RoutingPolicyRegistry registry = new RoutingPolicyRegistry(msg.sender);
        vm.stopBroadcast();

        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
        bytes memory constructorArgs = abi.encode(poolManager, registry);
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_FACTORY, flags, type(ChainLocalizedRoutingHook).creationCode, constructorArgs);

        vm.startBroadcast();
        ChainLocalizedRoutingHook hook = new ChainLocalizedRoutingHook{salt: salt}(poolManager, registry);
        registry.setHookAuthorization(address(hook), true);
        vm.stopBroadcast();

        require(address(hook) == hookAddress, "DeployHookScript: Hook Address Mismatch");

        console2.log("RoutingPolicyRegistry:", address(registry));
        console2.log("ChainLocalizedRoutingHook:", address(hook));
    }
}
