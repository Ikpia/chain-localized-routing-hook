// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";

import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";

import {EasyPosm} from "test/utils/libraries/EasyPosm.sol";
import {BaseTest} from "test/utils/BaseTest.sol";

import {ChainLocalizedRoutingHook} from "src/ChainLocalizedRoutingHook.sol";
import {RoutingPolicyRegistry} from "src/RoutingPolicyRegistry.sol";
import {PolicyTypes} from "src/libraries/PolicyTypes.sol";

contract ProfileLifecycleIntegrationTest is BaseTest {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using StateLibrary for IPoolManager;

    Currency internal currency0;
    Currency internal currency1;

    PoolKey internal poolKey;
    PoolId internal poolId;

    RoutingPolicyRegistry internal registry;
    ChainLocalizedRoutingHook internal hook;

    function setUp() public {
        deployArtifactsAndLabel();
        (currency0, currency1) = deployCurrencyPair();

        registry = new RoutingPolicyRegistry(address(this));

        address flags =
            address(uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG) ^ (uint160(0x7279) << 144));

        bytes memory constructorArgs = abi.encode(poolManager, registry);
        deployCodeTo("ChainLocalizedRoutingHook.sol:ChainLocalizedRoutingHook", constructorArgs, flags);
        hook = ChainLocalizedRoutingHook(flags);

        registry.setHookAuthorization(address(hook), true);

        poolKey = PoolKey({currency0: currency0, currency1: currency1, fee: 3000, tickSpacing: 60, hooks: IHooks(hook)});
        poolId = poolKey.toId();

        poolManager.initialize(poolKey, Constants.SQRT_PRICE_1_1);

        int24 tickLower = TickMath.minUsableTick(poolKey.tickSpacing);
        int24 tickUpper = TickMath.maxUsableTick(poolKey.tickSpacing);

        uint128 liquidityAmount = 100e18;
        (uint256 amount0Expected, uint256 amount1Expected) = LiquidityAmounts.getAmountsForLiquidity(
            Constants.SQRT_PRICE_1_1,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            liquidityAmount
        );

        positionManager.mint(
            poolKey,
            tickLower,
            tickUpper,
            liquidityAmount,
            amount0Expected + 1,
            amount1Expected + 1,
            address(this),
            block.timestamp,
            Constants.ZERO_BYTES
        );
    }

    function testProfileSpecificOutcomes() public {
        bytes memory traderData = abi.encode(address(swapRouter), address(this));

        // Base: high-throughput defaults -> allow medium sized swap.
        registry.setChainProfile(block.chainid, PolicyTypes.ChainProfile.BASE);
        PolicyTypes.PoolPolicy memory basePolicy;
        basePolicy.enabled = true;
        basePolicy.maxAmountIn = 2 ether;
        basePolicy.maxSwapsPerBlock = 20;
        basePolicy.maxPriceImpactBps = 0;
        registry.setPoolPolicy(block.chainid, PoolId.unwrap(poolId), basePolicy);

        swapRouter.swapExactTokensForTokens({
            amountIn: 0.5 ether,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: traderData,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        // Optimism: stricter limits -> same trade should fail.
        registry.setChainProfile(block.chainid, PolicyTypes.ChainProfile.OPTIMISM);
        PolicyTypes.PoolPolicy memory optimismPolicy;
        optimismPolicy.enabled = true;
        optimismPolicy.maxAmountIn = 0.2 ether;
        optimismPolicy.maxPriceImpactBps = 0;
        optimismPolicy.maxSwapsPerBlock = 6;
        optimismPolicy.cooldownSeconds = 1;
        registry.setPoolPolicy(block.chainid, PoolId.unwrap(poolId), optimismPolicy);

        vm.expectRevert();
        swapRouter.swapExactTokensForTokens({
            amountIn: 0.5 ether,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: traderData,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        // Arbitrum: allowlist mode -> same amount succeeds only once router is allowlisted.
        registry.setChainProfile(block.chainid, PolicyTypes.ChainProfile.ARBITRUM);
        PolicyTypes.PoolPolicy memory arbitrumPolicy;
        arbitrumPolicy.enabled = true;
        arbitrumPolicy.maxAmountIn = 1 ether;
        arbitrumPolicy.maxPriceImpactBps = 0;
        arbitrumPolicy.maxSwapsPerBlock = 20;
        arbitrumPolicy.cooldownSeconds = 0;
        arbitrumPolicy.enforceRouterAllowlist = true;
        registry.setPoolPolicy(block.chainid, PoolId.unwrap(poolId), arbitrumPolicy);

        vm.expectRevert();
        swapRouter.swapExactTokensForTokens({
            amountIn: 0.5 ether,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: traderData,
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        registry.setRouterAllowlist(block.chainid, PoolId.unwrap(poolId), address(swapRouter), true);

        swapRouter.swapExactTokensForTokens({
            amountIn: 0.5 ether,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: traderData,
            receiver: address(this),
            deadline: block.timestamp + 1
        });
    }
}
