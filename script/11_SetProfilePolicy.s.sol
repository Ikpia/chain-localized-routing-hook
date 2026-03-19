// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";

import {RoutingPolicyRegistry} from "src/RoutingPolicyRegistry.sol";
import {PolicyTypes} from "src/libraries/PolicyTypes.sol";

contract SetProfilePolicyScript is Script {
    function run() external {
        address registryAddress = vm.envAddress("REGISTRY");
        bytes32 poolId = vm.envBytes32("POOL_ID");
        uint256 chainId = vm.envOr("CHAIN_ID", block.chainid);
        uint8 profileId = uint8(vm.envUint("PROFILE_ID"));

        PolicyTypes.PoolPolicy memory policy;
        policy.enabled = vm.envOr("POLICY_ENABLED", true);
        policy.maxAmountIn = uint128(vm.envOr("MAX_AMOUNT_IN", uint256(1 ether)));
        policy.maxPriceImpactBps = uint24(vm.envOr("MAX_PRICE_IMPACT_BPS", uint256(1_000)));
        policy.cooldownSeconds = uint32(vm.envOr("COOLDOWN_SECONDS", uint256(0)));
        policy.maxSwapsPerBlock = uint16(vm.envOr("MAX_SWAPS_PER_BLOCK", uint256(20)));
        policy.enforceRouterAllowlist = vm.envOr("ENFORCE_ROUTER_ALLOWLIST", false);
        policy.enforceActorDenylist = vm.envOr("ENFORCE_ACTOR_DENYLIST", false);
        policy.dynamicFeeEnabled = vm.envOr("DYNAMIC_FEE_ENABLED", false);
        policy.baseFee = uint24(vm.envOr("BASE_FEE", uint256(3_000)));
        policy.gasPriceCeilingWei = uint64(vm.envOr("GAS_PRICE_CEILING_WEI", uint256(0)));

        RoutingPolicyRegistry registry = RoutingPolicyRegistry(registryAddress);

        vm.startBroadcast();
        registry.setChainProfile(chainId, PolicyTypes.ChainProfile(profileId));
        registry.setPoolPolicy(chainId, poolId, policy);
        vm.stopBroadcast();

        console2.log("Configured registry:", registryAddress);
        console2.log("ChainId:", chainId);
        console2.log("PoolId:");
        console2.logBytes32(poolId);
    }
}
