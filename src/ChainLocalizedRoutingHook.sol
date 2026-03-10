// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {BaseHook} from "@uniswap/v4-periphery/src/utils/BaseHook.sol";

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

import {IRoutingPolicyRegistry} from "src/interfaces/IRoutingPolicyRegistry.sol";
import {PolicyTypes} from "src/libraries/PolicyTypes.sol";

contract ChainLocalizedRoutingHook is BaseHook {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    error SwapBlockedByPolicy(uint8 reasonCode);

    event PolicyChecked(bytes32 indexed poolId, address indexed router, address indexed trader, bool allowed, uint8 reasonCode);

    IRoutingPolicyRegistry public immutable registry;

    mapping(bytes32 poolId => uint256 count) public allowedSwaps;
    mapping(bytes32 poolId => uint256 count) public blockedSwaps;

    constructor(IPoolManager _poolManager, IRoutingPolicyRegistry _registry) BaseHook(_poolManager) {
        registry = _registry;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function _beforeSwap(address sender, PoolKey calldata key, SwapParams calldata params, bytes calldata hookData)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        PoolId poolId = key.toId();
        bytes32 rawPoolId = PoolId.unwrap(poolId);

        (address router, address trader) = _decodeContext(sender, hookData);
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);
        uint128 liquidity = poolManager.getLiquidity(poolId);

        PolicyTypes.SwapContext memory context = PolicyTypes.SwapContext({
            chainId: block.chainid,
            poolId: rawPoolId,
            router: router,
            trader: trader,
            amountIn: _absolute(params.amountSpecified),
            sqrtPriceX96: sqrtPriceX96,
            sqrtPriceLimitX96: params.sqrtPriceLimitX96,
            liquidity: liquidity,
            gasPriceWei: tx.gasprice
        });

        PolicyTypes.PolicyDecision memory decision = registry.validateAndRecordSwap(context);
        if (!decision.allowed) {
            unchecked {
                blockedSwaps[rawPoolId]++;
            }
            emit PolicyChecked(rawPoolId, router, trader, false, decision.reasonCode);
            revert SwapBlockedByPolicy(decision.reasonCode);
        }

        unchecked {
            allowedSwaps[rawPoolId]++;
        }
        emit PolicyChecked(rawPoolId, router, trader, true, decision.reasonCode);

        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, decision.feeOverride);
    }

    function _afterSwap(address, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata)
        internal
        pure
        override
        returns (bytes4, int128)
    {
        return (BaseHook.afterSwap.selector, 0);
    }

    function _decodeContext(address sender, bytes calldata hookData) internal pure returns (address router, address trader) {
        router = sender;
        trader = sender;

        if (hookData.length == 64) {
            (address decodedRouter, address decodedTrader) = abi.decode(hookData, (address, address));
            if (decodedRouter != address(0)) {
                router = decodedRouter;
            }
            if (decodedTrader != address(0)) {
                trader = decodedTrader;
            }
            return (router, trader);
        }

        if (hookData.length == 32) {
            address decodedTrader = abi.decode(hookData, (address));
            if (decodedTrader != address(0)) {
                trader = decodedTrader;
            }
        }
    }

    function _absolute(int256 value) internal pure returns (uint256) {
        if (value >= 0) {
            return uint256(value);
        }

        if (value == type(int256).min) {
            return uint256(type(int256).max) + 1;
        }

        return uint256(-value);
    }
}
