// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

library PolicyTypes {
    enum ChainProfile {
        UNSPECIFIED,
        BASE,
        OPTIMISM,
        ARBITRUM
    }

    enum ReasonCode {
        ALLOWED,
        POLICY_DISABLED,
        SWAP_TOO_LARGE,
        PRICE_IMPACT_TOO_HIGH,
        COOLDOWN_ACTIVE,
        SWAPS_PER_BLOCK_EXCEEDED,
        ROUTER_NOT_ALLOWLISTED,
        ACTOR_DENIED,
        GAS_PRICE_TOO_HIGH
    }

    struct PoolPolicy {
        bool enabled;
        uint128 maxAmountIn;
        uint24 maxPriceImpactBps;
        uint32 cooldownSeconds;
        uint16 maxSwapsPerBlock;
        bool enforceRouterAllowlist;
        bool enforceActorDenylist;
        bool dynamicFeeEnabled;
        uint24 baseFee;
        uint64 gasPriceCeilingWei;
    }

    struct SwapContext {
        uint256 chainId;
        bytes32 poolId;
        address router;
        address trader;
        uint256 amountIn;
        uint160 sqrtPriceX96;
        uint160 sqrtPriceLimitX96;
        uint128 liquidity;
        uint256 gasPriceWei;
    }

    struct PolicyDecision {
        bool allowed;
        uint8 reasonCode;
        uint24 feeOverride;
    }
}
