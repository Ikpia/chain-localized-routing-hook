// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

import {RoutingPolicyRegistry} from "src/RoutingPolicyRegistry.sol";
import {PolicyTypes} from "src/libraries/PolicyTypes.sol";

contract RoutingPolicyRegistryFuzzTest is Test {
    RoutingPolicyRegistry internal registry;

    address internal owner = address(this);
    address internal hook = address(0xA11CE);

    uint256 internal constant CHAIN_ID = 84_532;
    bytes32 internal constant POOL_ID = keccak256("fuzz-pool");

    function setUp() public {
        registry = new RoutingPolicyRegistry(owner);
        registry.setHookAuthorization(hook, true);

        PolicyTypes.PoolPolicy memory policy;
        policy.enabled = true;
        policy.maxPriceImpactBps = 10_000;
        policy.maxSwapsPerBlock = 1_000;
        registry.setPoolPolicy(CHAIN_ID, POOL_ID, policy);
    }

    function testFuzz_MaxAmountNeverBypassed(uint96 maxAmountIn, uint96 amountIn) public {
        PolicyTypes.PoolPolicy memory policy = registry.getPoolPolicy(CHAIN_ID, POOL_ID);
        policy.maxAmountIn = maxAmountIn;
        policy.maxSwapsPerBlock = 1_000;
        registry.setPoolPolicy(CHAIN_ID, POOL_ID, policy);

        vm.prank(hook);
        PolicyTypes.PolicyDecision memory decision = registry.validateAndRecordSwap(_context(amountIn, 0));

        if (maxAmountIn == 0 || amountIn <= maxAmountIn) {
            assertTrue(decision.allowed);
        } else {
            assertFalse(decision.allowed);
            assertEq(decision.reasonCode, uint8(PolicyTypes.ReasonCode.SWAP_TOO_LARGE));
        }
    }

    function testFuzz_GasCeilingAlwaysEnforced(uint64 gasCeilingWei, uint64 txGasPriceWei) public {
        PolicyTypes.PoolPolicy memory policy = registry.getPoolPolicy(CHAIN_ID, POOL_ID);
        policy.gasPriceCeilingWei = gasCeilingWei;
        policy.maxSwapsPerBlock = 1_000;
        registry.setPoolPolicy(CHAIN_ID, POOL_ID, policy);

        vm.prank(hook);
        PolicyTypes.PolicyDecision memory decision = registry.validateAndRecordSwap(_context(1 ether, txGasPriceWei));

        if (gasCeilingWei == 0 || txGasPriceWei <= gasCeilingWei) {
            assertTrue(decision.allowed);
        } else {
            assertFalse(decision.allowed);
            assertEq(decision.reasonCode, uint8(PolicyTypes.ReasonCode.GAS_PRICE_TOO_HIGH));
        }
    }

    function _context(uint256 amountIn, uint256 gasPriceWei)
        private
        pure
        returns (PolicyTypes.SwapContext memory ctx)
    {
        ctx.chainId = CHAIN_ID;
        ctx.poolId = POOL_ID;
        ctx.router = address(0x1234);
        ctx.trader = address(0x5678);
        ctx.amountIn = amountIn;
        ctx.sqrtPriceX96 = 2 ** 96;
        ctx.sqrtPriceLimitX96 = 2 ** 96;
        ctx.liquidity = 1_000_000;
        ctx.gasPriceWei = gasPriceWei;
    }
}
