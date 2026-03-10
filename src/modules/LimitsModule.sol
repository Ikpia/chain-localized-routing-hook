// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

library LimitsModule {
    uint24 internal constant MAX_BPS = 10_000;

    function approximatePriceImpactBps(uint160 currentSqrtPriceX96, uint160 sqrtPriceLimitX96)
        internal
        pure
        returns (uint24)
    {
        if (currentSqrtPriceX96 == 0 || sqrtPriceLimitX96 == 0) {
            return 0;
        }

        uint256 current = uint256(currentSqrtPriceX96);
        uint256 limit = uint256(sqrtPriceLimitX96);
        uint256 diff = current > limit ? current - limit : limit - current;

        uint256 impact = (diff * MAX_BPS) / current;
        if (impact > type(uint24).max) {
            return type(uint24).max;
        }

        return uint24(impact);
    }
}
