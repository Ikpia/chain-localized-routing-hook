// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

import {LPFeeLibrary} from "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";

import {PolicyTypes} from "src/libraries/PolicyTypes.sol";
import {FeePolicyModule} from "src/modules/FeePolicyModule.sol";

contract FeePolicyModuleHarness {
    function compute(PolicyTypes.ChainProfile profile, PolicyTypes.PoolPolicy memory policy, uint256 gasPriceWei)
        external
        pure
        returns (uint24)
    {
        return FeePolicyModule.computeFeeOverride(profile, policy, gasPriceWei);
    }
}

contract FeePolicyModuleTest is Test {
    FeePolicyModuleHarness internal harness;

    function setUp() public {
        harness = new FeePolicyModuleHarness();
    }

    function testDisabledDynamicFeeReturnsZero() public view {
        PolicyTypes.PoolPolicy memory policy;
        policy.dynamicFeeEnabled = false;

        uint24 fee = harness.compute(PolicyTypes.ChainProfile.BASE, policy, 1 gwei);
        assertEq(fee, 0);
    }

    function testDefaultsPerProfileWhenBaseFeeUnset() public view {
        PolicyTypes.PoolPolicy memory policy;
        policy.dynamicFeeEnabled = true;

        assertEq(
            harness.compute(PolicyTypes.ChainProfile.BASE, policy, 0),
            uint24(2_500 | LPFeeLibrary.OVERRIDE_FEE_FLAG)
        );
        assertEq(
            harness.compute(PolicyTypes.ChainProfile.OPTIMISM, policy, 0),
            uint24(3_000 | LPFeeLibrary.OVERRIDE_FEE_FLAG)
        );
        assertEq(
            harness.compute(PolicyTypes.ChainProfile.ARBITRUM, policy, 0),
            uint24(4_000 | LPFeeLibrary.OVERRIDE_FEE_FLAG)
        );
        assertEq(
            harness.compute(PolicyTypes.ChainProfile.UNSPECIFIED, policy, 0),
            uint24(3_000 | LPFeeLibrary.OVERRIDE_FEE_FLAG)
        );
    }

    function testArbitrumCongestionAdjustmentAtThreshold() public view {
        PolicyTypes.PoolPolicy memory policy;
        policy.dynamicFeeEnabled = true;
        policy.baseFee = 4_000;
        policy.gasPriceCeilingWei = 100;

        uint24 below = harness.compute(PolicyTypes.ChainProfile.ARBITRUM, policy, 79);
        uint24 atThreshold = harness.compute(PolicyTypes.ChainProfile.ARBITRUM, policy, 80);

        assertEq(below, uint24(4_000 | LPFeeLibrary.OVERRIDE_FEE_FLAG));
        assertEq(atThreshold, uint24(5_500 | LPFeeLibrary.OVERRIDE_FEE_FLAG));
    }

    function testOptimismAdjustmentAtCeiling() public view {
        PolicyTypes.PoolPolicy memory policy;
        policy.dynamicFeeEnabled = true;
        policy.baseFee = 3_000;
        policy.gasPriceCeilingWei = 100;

        uint24 below = harness.compute(PolicyTypes.ChainProfile.OPTIMISM, policy, 99);
        uint24 atCeiling = harness.compute(PolicyTypes.ChainProfile.OPTIMISM, policy, 100);

        assertEq(below, uint24(3_000 | LPFeeLibrary.OVERRIDE_FEE_FLAG));
        assertEq(atCeiling, uint24(3_500 | LPFeeLibrary.OVERRIDE_FEE_FLAG));
    }

    function testClampsToMaxLpFee() public view {
        PolicyTypes.PoolPolicy memory policy;
        policy.dynamicFeeEnabled = true;
        policy.baseFee = uint24(LPFeeLibrary.MAX_LP_FEE);
        policy.gasPriceCeilingWei = 1;

        uint24 capped = harness.compute(PolicyTypes.ChainProfile.OPTIMISM, policy, 1);
        assertEq(capped, uint24(LPFeeLibrary.MAX_LP_FEE | LPFeeLibrary.OVERRIDE_FEE_FLAG));
    }

    function testBoundedAddOverflowBranchSaturates() public view {
        PolicyTypes.PoolPolicy memory policy;
        policy.dynamicFeeEnabled = true;
        policy.baseFee = type(uint24).max;
        policy.gasPriceCeilingWei = 1;

        uint24 capped = harness.compute(PolicyTypes.ChainProfile.OPTIMISM, policy, 1);
        assertEq(capped, uint24(LPFeeLibrary.MAX_LP_FEE | LPFeeLibrary.OVERRIDE_FEE_FLAG));
    }
}
