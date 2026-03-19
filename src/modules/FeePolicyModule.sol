// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";

import {PolicyTypes} from "src/libraries/PolicyTypes.sol";

library FeePolicyModule {
    function computeFeeOverride(
        PolicyTypes.ChainProfile profile,
        PolicyTypes.PoolPolicy memory policy,
        uint256 gasPriceWei
    ) internal pure returns (uint24) {
        if (!policy.dynamicFeeEnabled) {
            return 0;
        }

        uint24 baseFee = policy.baseFee;
        if (baseFee == 0) {
            baseFee = _defaultFee(profile);
        }

        uint24 adjusted = baseFee;
        if (profile == PolicyTypes.ChainProfile.ARBITRUM && policy.gasPriceCeilingWei > 0) {
            uint256 threshold = uint256(policy.gasPriceCeilingWei) * 8 / 10;
            if (gasPriceWei >= threshold) {
                adjusted = _boundedAdd(baseFee, 1_500);
            }
        } else if (profile == PolicyTypes.ChainProfile.OPTIMISM && policy.gasPriceCeilingWei > 0) {
            if (gasPriceWei >= uint256(policy.gasPriceCeilingWei)) {
                adjusted = _boundedAdd(baseFee, 500);
            }
        }

        if (adjusted > LPFeeLibrary.MAX_LP_FEE) {
            adjusted = LPFeeLibrary.MAX_LP_FEE;
        }

        return adjusted | LPFeeLibrary.OVERRIDE_FEE_FLAG;
    }

    function _defaultFee(PolicyTypes.ChainProfile profile) private pure returns (uint24) {
        if (profile == PolicyTypes.ChainProfile.BASE) {
            return 2_500;
        }
        if (profile == PolicyTypes.ChainProfile.OPTIMISM) {
            return 3_000;
        }
        if (profile == PolicyTypes.ChainProfile.ARBITRUM) {
            return 4_000;
        }
        return 3_000;
    }

    function _boundedAdd(uint24 a, uint24 b) private pure returns (uint24) {
        uint256 c = uint256(a) + uint256(b);
        if (c > type(uint24).max) {
            return type(uint24).max;
        }
        return uint24(c);
    }
}
