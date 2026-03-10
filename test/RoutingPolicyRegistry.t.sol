// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

import {RoutingPolicyRegistry} from "src/RoutingPolicyRegistry.sol";
import {PolicyTypes} from "src/libraries/PolicyTypes.sol";

contract RoutingPolicyRegistryTest is Test {
    event PolicySet(uint256 indexed chainId, bytes32 indexed poolId, bytes32 policyHash);
    event SwapAllowed(uint256 indexed chainId, bytes32 indexed poolId, address indexed trader, uint8 reasonCode);
    event SwapBlocked(uint256 indexed chainId, bytes32 indexed poolId, address indexed trader, uint8 reasonCode);
    event RouterAllowlistUpdated(uint256 indexed chainId, address indexed router, bool allowed);

    RoutingPolicyRegistry internal registry;

    address internal owner = address(0xA11CE);
    address internal hook = address(0xBEEF);
    address internal other = address(0xDEAD);
    address internal trader = address(0xCAFE);

    uint256 internal constant CHAIN_ID = 84_532;
    bytes32 internal constant POOL_ID = keccak256("pool:base-op-arb");

    function setUp() public {
        vm.prank(owner);
        registry = new RoutingPolicyRegistry(owner);

        vm.prank(owner);
        registry.setHookAuthorization(hook, true);

        vm.prank(owner);
        registry.setChainProfile(CHAIN_ID, PolicyTypes.ChainProfile.BASE);
    }

    function testSetPoolPolicyEmitsHash() public {
        PolicyTypes.PoolPolicy memory policy = _policyEnabled();

        bytes32 expectedHash = keccak256(abi.encode(policy));
        vm.expectEmit(true, true, false, true, address(registry));
        emit PolicySet(CHAIN_ID, POOL_ID, expectedHash);

        vm.prank(owner);
        registry.setPoolPolicy(CHAIN_ID, POOL_ID, policy);
    }

    function testUnauthorizedOwnerActionReverts() public {
        vm.expectRevert(RoutingPolicyRegistry.NotOwner.selector);
        registry.setChainProfile(CHAIN_ID, PolicyTypes.ChainProfile.OPTIMISM);
    }

    function testValidateUnauthorizedHookReverts() public {
        vm.prank(owner);
        registry.setPoolPolicy(CHAIN_ID, POOL_ID, _policyEnabled());

        vm.expectRevert(RoutingPolicyRegistry.UnauthorizedHook.selector);
        registry.validateAndRecordSwap(_context(1 ether, address(0x1111), trader, 0));
    }

    function testPolicyDisabledAllowsSwap() public {
        PolicyTypes.PoolPolicy memory policy = _policyEnabled();
        policy.enabled = false;

        vm.prank(owner);
        registry.setPoolPolicy(CHAIN_ID, POOL_ID, policy);

        vm.expectEmit(true, true, true, true, address(registry));
        emit SwapAllowed(CHAIN_ID, POOL_ID, trader, uint8(PolicyTypes.ReasonCode.POLICY_DISABLED));

        vm.prank(hook);
        PolicyTypes.PolicyDecision memory decision =
            registry.validateAndRecordSwap(_context(1 ether, address(0x1111), trader, 0));

        assertTrue(decision.allowed);
        assertEq(decision.reasonCode, uint8(PolicyTypes.ReasonCode.POLICY_DISABLED));
    }

    function testMaxAmountBoundary() public {
        PolicyTypes.PoolPolicy memory policy = _policyEnabled();
        policy.maxAmountIn = 10;

        vm.prank(owner);
        registry.setPoolPolicy(CHAIN_ID, POOL_ID, policy);

        vm.prank(hook);
        PolicyTypes.PolicyDecision memory atBoundary = registry.validateAndRecordSwap(_context(10, other, trader, 0));
        assertTrue(atBoundary.allowed);

        vm.expectEmit(true, true, true, true, address(registry));
        emit SwapBlocked(CHAIN_ID, POOL_ID, trader, uint8(PolicyTypes.ReasonCode.SWAP_TOO_LARGE));

        vm.prank(hook);
        PolicyTypes.PolicyDecision memory aboveBoundary = registry.validateAndRecordSwap(_context(11, other, trader, 0));
        assertFalse(aboveBoundary.allowed);
        assertEq(aboveBoundary.reasonCode, uint8(PolicyTypes.ReasonCode.SWAP_TOO_LARGE));
    }

    function testCooldownBoundary() public {
        PolicyTypes.PoolPolicy memory policy = _policyEnabled();
        policy.cooldownSeconds = 10;

        vm.prank(owner);
        registry.setPoolPolicy(CHAIN_ID, POOL_ID, policy);

        vm.prank(hook);
        PolicyTypes.PolicyDecision memory first = registry.validateAndRecordSwap(_context(1, other, trader, 0));
        assertTrue(first.allowed);

        vm.prank(hook);
        PolicyTypes.PolicyDecision memory blocked = registry.validateAndRecordSwap(_context(1, other, trader, 0));
        assertFalse(blocked.allowed);
        assertEq(blocked.reasonCode, uint8(PolicyTypes.ReasonCode.COOLDOWN_ACTIVE));

        vm.warp(block.timestamp + 10);

        vm.prank(hook);
        PolicyTypes.PolicyDecision memory afterCooldown = registry.validateAndRecordSwap(_context(1, other, trader, 0));
        assertTrue(afterCooldown.allowed);
    }

    function testSwapsPerBlockBoundary() public {
        PolicyTypes.PoolPolicy memory policy = _policyEnabled();
        policy.maxSwapsPerBlock = 2;

        vm.prank(owner);
        registry.setPoolPolicy(CHAIN_ID, POOL_ID, policy);

        vm.startPrank(hook);
        assertTrue(registry.validateAndRecordSwap(_context(1, other, trader, 0)).allowed);
        assertTrue(registry.validateAndRecordSwap(_context(1, other, trader, 0)).allowed);

        PolicyTypes.PolicyDecision memory blocked = registry.validateAndRecordSwap(_context(1, other, trader, 0));
        vm.stopPrank();

        assertFalse(blocked.allowed);
        assertEq(blocked.reasonCode, uint8(PolicyTypes.ReasonCode.SWAPS_PER_BLOCK_EXCEEDED));
    }

    function testAllowlistAndDenylistBoundaries() public {
        PolicyTypes.PoolPolicy memory policy = _policyEnabled();
        policy.enforceRouterAllowlist = true;
        policy.enforceActorDenylist = true;

        vm.prank(owner);
        registry.setPoolPolicy(CHAIN_ID, POOL_ID, policy);

        vm.prank(owner);
        registry.setRouterAllowlist(CHAIN_ID, POOL_ID, other, true);

        vm.expectEmit(true, true, false, true, address(registry));
        emit RouterAllowlistUpdated(CHAIN_ID, other, true);

        vm.prank(owner);
        registry.setRouterAllowlist(CHAIN_ID, POOL_ID, other, true);

        vm.prank(owner);
        registry.setActorDenylist(CHAIN_ID, POOL_ID, trader, true);

        vm.prank(hook);
        PolicyTypes.PolicyDecision memory denied = registry.validateAndRecordSwap(_context(1, other, trader, 0));
        assertFalse(denied.allowed);
        assertEq(denied.reasonCode, uint8(PolicyTypes.ReasonCode.ACTOR_DENIED));

        vm.prank(owner);
        registry.setActorDenylist(CHAIN_ID, POOL_ID, trader, false);

        vm.prank(hook);
        PolicyTypes.PolicyDecision memory allowed = registry.validateAndRecordSwap(_context(1, other, trader, 0));
        assertTrue(allowed.allowed);

        vm.prank(hook);
        PolicyTypes.PolicyDecision memory blockedRouter =
            registry.validateAndRecordSwap(_context(1, address(0x1234), trader, 0));
        assertFalse(blockedRouter.allowed);
        assertEq(blockedRouter.reasonCode, uint8(PolicyTypes.ReasonCode.ROUTER_NOT_ALLOWLISTED));
    }

    function testInvalidPolicyUpdateReverts() public {
        PolicyTypes.PoolPolicy memory policy = _policyEnabled();
        policy.maxPriceImpactBps = 10_001;

        vm.prank(owner);
        vm.expectRevert(RoutingPolicyRegistry.InvalidPolicy.selector);
        registry.setPoolPolicy(CHAIN_ID, POOL_ID, policy);
    }

    function _policyEnabled() private pure returns (PolicyTypes.PoolPolicy memory policy) {
        policy.enabled = true;
        policy.maxAmountIn = 100 ether;
        policy.maxPriceImpactBps = 1_000;
        policy.cooldownSeconds = 0;
        policy.maxSwapsPerBlock = 100;
        policy.enforceRouterAllowlist = false;
        policy.enforceActorDenylist = false;
        policy.dynamicFeeEnabled = false;
        policy.baseFee = 3_000;
        policy.gasPriceCeilingWei = 0;
    }

    function _context(uint256 amountIn, address router, address actor, uint160 limit)
        private
        pure
        returns (PolicyTypes.SwapContext memory)
    {
        return PolicyTypes.SwapContext({
            chainId: CHAIN_ID,
            poolId: POOL_ID,
            router: router,
            trader: actor,
            amountIn: amountIn,
            sqrtPriceX96: 2 ** 96,
            sqrtPriceLimitX96: limit,
            liquidity: 1_000_000,
            gasPriceWei: 0
        });
    }
}
