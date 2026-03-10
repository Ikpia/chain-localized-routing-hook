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
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";

import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {Constants} from "@uniswap/v4-core/test/utils/Constants.sol";

import {EasyPosm} from "test/utils/libraries/EasyPosm.sol";
import {BaseTest} from "test/utils/BaseTest.sol";

import {ChainLocalizedRoutingHook} from "src/ChainLocalizedRoutingHook.sol";
import {RoutingPolicyRegistry} from "src/RoutingPolicyRegistry.sol";
import {PolicyTypes} from "src/libraries/PolicyTypes.sol";

contract ChainLocalizedRoutingHookTest is BaseTest {
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

    uint256 internal tokenId;

    function setUp() public {
        deployArtifactsAndLabel();
        (currency0, currency1) = deployCurrencyPair();

        registry = new RoutingPolicyRegistry(address(this));

        address flags =
            address(uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG) ^ (uint160(0x7277) << 144));

        bytes memory constructorArgs = abi.encode(poolManager, registry);
        deployCodeTo("ChainLocalizedRoutingHook.sol:ChainLocalizedRoutingHook", constructorArgs, flags);
        hook = ChainLocalizedRoutingHook(flags);

        registry.setHookAuthorization(address(hook), true);
        registry.setChainProfile(block.chainid, PolicyTypes.ChainProfile.BASE);

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

        (tokenId,) = positionManager.mint(
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

        registry.setPoolPolicy(block.chainid, PoolId.unwrap(poolId), _defaultPolicy());
    }

    function testSwapAllowedAndCounted() public {
        uint256 amountIn = 1e18;

        BalanceDelta swapDelta = swapRouter.swapExactTokensForTokens({
            amountIn: amountIn,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: abi.encode(address(swapRouter), address(this)),
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        assertEq(int256(swapDelta.amount0()), -int256(amountIn));
        assertEq(hook.allowedSwaps(PoolId.unwrap(poolId)), 1);
        assertEq(hook.blockedSwaps(PoolId.unwrap(poolId)), 0);
    }

    function testSwapBlockedByMaxAmount() public {
        PolicyTypes.PoolPolicy memory policy = _defaultPolicy();
        policy.maxAmountIn = 0.25 ether;
        registry.setPoolPolicy(block.chainid, PoolId.unwrap(poolId), policy);

        vm.expectRevert();
        swapRouter.swapExactTokensForTokens({
            amountIn: 1 ether,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: abi.encode(address(swapRouter), address(this)),
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        assertEq(hook.allowedSwaps(PoolId.unwrap(poolId)), 0);
    }

    function testCooldownBoundaryInHook() public {
        PolicyTypes.PoolPolicy memory policy = _defaultPolicy();
        policy.cooldownSeconds = 10;
        registry.setPoolPolicy(block.chainid, PoolId.unwrap(poolId), policy);

        swapRouter.swapExactTokensForTokens({
            amountIn: 0.1 ether,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: abi.encode(address(swapRouter), address(this)),
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        vm.expectRevert();
        swapRouter.swapExactTokensForTokens({
            amountIn: 0.1 ether,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: abi.encode(address(swapRouter), address(this)),
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        vm.warp(block.timestamp + 10);

        swapRouter.swapExactTokensForTokens({
            amountIn: 0.1 ether,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: abi.encode(address(swapRouter), address(this)),
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        assertEq(hook.allowedSwaps(PoolId.unwrap(poolId)), 2);
    }

    function testAllowlistAndDenylistViaHookData() public {
        PolicyTypes.PoolPolicy memory policy = _defaultPolicy();
        policy.enforceRouterAllowlist = true;
        policy.enforceActorDenylist = true;
        registry.setPoolPolicy(block.chainid, PoolId.unwrap(poolId), policy);

        vm.expectRevert();
        swapRouter.swapExactTokensForTokens({
            amountIn: 0.1 ether,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: abi.encode(address(swapRouter), address(this)),
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        registry.setRouterAllowlist(block.chainid, PoolId.unwrap(poolId), address(swapRouter), true);
        registry.setActorDenylist(block.chainid, PoolId.unwrap(poolId), address(this), true);

        vm.expectRevert();
        swapRouter.swapExactTokensForTokens({
            amountIn: 0.1 ether,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: abi.encode(address(swapRouter), address(this)),
            receiver: address(this),
            deadline: block.timestamp + 1
        });

        registry.setActorDenylist(block.chainid, PoolId.unwrap(poolId), address(this), false);

        swapRouter.swapExactTokensForTokens({
            amountIn: 0.1 ether,
            amountOutMin: 0,
            zeroForOne: true,
            poolKey: poolKey,
            hookData: abi.encode(address(swapRouter), address(this)),
            receiver: address(this),
            deadline: block.timestamp + 1
        });
    }

    function testPermissionBitMismatchRevertsOnDeployment() public {
        address wrongFlags = address(uint160(Hooks.BEFORE_SWAP_FLAG) ^ (uint160(0x7278) << 144));
        bytes memory constructorArgs = abi.encode(poolManager, registry);

        vm.expectRevert();
        deployCodeTo("ChainLocalizedRoutingHook.sol:ChainLocalizedRoutingHook", constructorArgs, wrongFlags);
    }

    function _defaultPolicy() private pure returns (PolicyTypes.PoolPolicy memory policy) {
        policy.enabled = true;
        policy.maxAmountIn = 10 ether;
        policy.maxPriceImpactBps = 0;
        policy.cooldownSeconds = 0;
        policy.maxSwapsPerBlock = 100;
        policy.enforceRouterAllowlist = false;
        policy.enforceActorDenylist = false;
        policy.dynamicFeeEnabled = false;
        policy.baseFee = 0;
        policy.gasPriceCeilingWei = 0;
    }
}
