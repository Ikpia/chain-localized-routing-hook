// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {PolicyTypes} from "src/libraries/PolicyTypes.sol";

interface IRoutingPolicyRegistry {
    event PolicySet(uint256 indexed chainId, bytes32 indexed poolId, bytes32 policyHash);
    event SwapAllowed(uint256 indexed chainId, bytes32 indexed poolId, address indexed trader, uint8 reasonCode);
    event SwapBlocked(uint256 indexed chainId, bytes32 indexed poolId, address indexed trader, uint8 reasonCode);
    event RouterAllowlistUpdated(uint256 indexed chainId, address indexed router, bool allowed);

    function getChainProfile(uint256 chainId) external view returns (PolicyTypes.ChainProfile);
    function getPoolPolicy(uint256 chainId, bytes32 poolId) external view returns (PolicyTypes.PoolPolicy memory);

    function validateAndRecordSwap(PolicyTypes.SwapContext calldata context)
        external
        returns (PolicyTypes.PolicyDecision memory);
}
