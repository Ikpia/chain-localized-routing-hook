// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";

import {RoutingPolicyRegistry} from "src/RoutingPolicyRegistry.sol";
import {PolicyTypes} from "src/libraries/PolicyTypes.sol";

contract PolicyInvariantHandler {
    RoutingPolicyRegistry public immutable registry;

    uint256 public immutable chainId;
    bytes32 public immutable poolId;
    uint256 public immutable maxAmount;

    uint256 public violationCount;

    constructor(RoutingPolicyRegistry _registry, uint256 _chainId, bytes32 _poolId, uint256 _maxAmount) {
        registry = _registry;
        chainId = _chainId;
        poolId = _poolId;
        maxAmount = _maxAmount;
    }

    function callValidate(uint256 rawAmount) external {
        uint256 amount = bound(rawAmount, 0, maxAmount * 2 + 1);

        PolicyTypes.SwapContext memory ctx = PolicyTypes.SwapContext({
            chainId: chainId,
            poolId: poolId,
            router: address(0x1234),
            trader: address(0x9999),
            amountIn: amount,
            sqrtPriceX96: 2 ** 96,
            sqrtPriceLimitX96: 2 ** 96,
            liquidity: 1_000_000,
            gasPriceWei: 0
        });

        PolicyTypes.PolicyDecision memory decision = registry.validateAndRecordSwap(ctx);

        bool shouldAllow = amount <= maxAmount;
        if (decision.allowed != shouldAllow) {
            unchecked {
                violationCount++;
            }
        }
    }

    function bound(uint256 x, uint256 min, uint256 max) internal pure returns (uint256) {
        if (x < min) return min;
        if (x > max) return max;
        return x;
    }
}

contract RoutingPolicyRegistryInvariantTest is StdInvariant, Test {
    RoutingPolicyRegistry internal registry;
    PolicyInvariantHandler internal handler;

    uint256 internal constant CHAIN_ID = 84_532;
    bytes32 internal constant POOL_ID = keccak256("invariant-pool");
    uint256 internal constant MAX_AMOUNT = 1 ether;

    function setUp() public {
        registry = new RoutingPolicyRegistry(address(this));

        PolicyTypes.PoolPolicy memory policy;
        policy.enabled = true;
        policy.maxAmountIn = uint128(MAX_AMOUNT);
        policy.maxPriceImpactBps = 10_000;
        policy.maxSwapsPerBlock = 1_000;
        registry.setPoolPolicy(CHAIN_ID, POOL_ID, policy);

        handler = new PolicyInvariantHandler(registry, CHAIN_ID, POOL_ID, MAX_AMOUNT);
        registry.setHookAuthorization(address(handler), true);

        targetContract(address(handler));
    }

    function invariant_MaxAmountRuleNeverBypassed() public view {
        assertEq(handler.violationCount(), 0);
    }
}
