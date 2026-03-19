// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

import {LimitsModule} from "src/modules/LimitsModule.sol";

contract LimitsModuleHarness {
    function approximate(uint160 currentSqrtPriceX96, uint160 sqrtPriceLimitX96) external pure returns (uint24) {
        return LimitsModule.approximatePriceImpactBps(currentSqrtPriceX96, sqrtPriceLimitX96);
    }
}

contract LimitsModuleTest is Test {
    LimitsModuleHarness internal harness;

    function setUp() public {
        harness = new LimitsModuleHarness();
    }

    function testReturnsZeroIfCurrentPriceIsZero() public view {
        assertEq(harness.approximate(0, 1), 0);
    }

    function testReturnsZeroIfLimitPriceIsZero() public view {
        assertEq(harness.approximate(1, 0), 0);
    }

    function testComputesImpactInBps() public view {
        // diff = 100, current = 1_000 => 10%
        assertEq(harness.approximate(1_000, 900), 1_000);
        assertEq(harness.approximate(1_000, 1_100), 1_000);
    }

    function testCapsImpactAtUint24Max() public view {
        uint24 impact = harness.approximate(1, type(uint160).max);
        assertEq(impact, type(uint24).max);
    }
}
