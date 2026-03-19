// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";

import {RoutingPolicyRegistry} from "src/RoutingPolicyRegistry.sol";
import {PolicyTypes} from "src/libraries/PolicyTypes.sol";

contract SeedDefaultPolicyScript is Script {
    function run() external {
        address registryAddress = vm.envAddress("REGISTRY");
        bytes32 poolId = vm.envBytes32("POOL_ID");
        uint256 chainId = vm.envOr("CHAIN_ID", block.chainid);
        uint8 profileId = uint8(vm.envUint("PROFILE_ID"));
        uint128 liquidityReference = uint128(vm.envOr("LIQUIDITY_REFERENCE", uint256(100 ether)));

        RoutingPolicyRegistry registry = RoutingPolicyRegistry(registryAddress);

        vm.startBroadcast();
        registry.setChainProfile(chainId, PolicyTypes.ChainProfile(profileId));
        registry.seedDefaultPolicy(chainId, poolId, liquidityReference);
        vm.stopBroadcast();

        console2.log("Seeded default policy for registry:", registryAddress);
        console2.log("ChainId:", chainId);
        console2.log("Liquidity reference:", liquidityReference);
    }
}
