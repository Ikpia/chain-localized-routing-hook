// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

import {BaseHook} from "@uniswap/v4-periphery/src/utils/BaseHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

import {ChainLocalizedRoutingHook} from "src/ChainLocalizedRoutingHook.sol";
import {RoutingPolicyRegistry} from "src/RoutingPolicyRegistry.sol";
import {IRoutingPolicyRegistry} from "src/interfaces/IRoutingPolicyRegistry.sol";

contract HookInternalHarness is ChainLocalizedRoutingHook {
    constructor(IRoutingPolicyRegistry registry) ChainLocalizedRoutingHook(IPoolManager(address(0)), registry) {}

    function validateHookAddress(BaseHook) internal pure override {}

    function exposedDecode(address sender, bytes calldata hookData) external pure returns (address router, address trader) {
        return _decodeContext(sender, hookData);
    }

    function exposedAbsolute(int256 value) external pure returns (uint256) {
        return _absolute(value);
    }
}

contract ChainLocalizedRoutingHookInternalTest is Test {
    HookInternalHarness internal harness;

    function setUp() public {
        RoutingPolicyRegistry registry = new RoutingPolicyRegistry(address(this));
        harness = new HookInternalHarness(registry);
    }

    function testDecodeContext64UsesProvidedAddresses() public view {
        address sender = address(0xABCD);
        address router = address(0x1010);
        address trader = address(0x2020);

        (address decodedRouter, address decodedTrader) = harness.exposedDecode(sender, abi.encode(router, trader));

        assertEq(decodedRouter, router);
        assertEq(decodedTrader, trader);
    }

    function testDecodeContext64FallsBackToSenderForZeroValues() public view {
        address sender = address(0xABCD);
        (address decodedRouter, address decodedTrader) = harness.exposedDecode(sender, abi.encode(address(0), address(0)));

        assertEq(decodedRouter, sender);
        assertEq(decodedTrader, sender);
    }

    function testDecodeContext32OverridesTraderOnly() public view {
        address sender = address(0xABCD);
        address trader = address(0x2020);

        (address decodedRouter, address decodedTrader) = harness.exposedDecode(sender, abi.encode(trader));

        assertEq(decodedRouter, sender);
        assertEq(decodedTrader, trader);
    }

    function testDecodeContext32WithZeroTraderFallsBack() public view {
        address sender = address(0xABCD);
        (address decodedRouter, address decodedTrader) = harness.exposedDecode(sender, abi.encode(address(0)));

        assertEq(decodedRouter, sender);
        assertEq(decodedTrader, sender);
    }

    function testDecodeContextOtherLengthFallsBack() public view {
        address sender = address(0xABCD);
        (address decodedRouter, address decodedTrader) = harness.exposedDecode(sender, hex"deadc0de");

        assertEq(decodedRouter, sender);
        assertEq(decodedTrader, sender);
    }

    function testAbsolutePositive() public view {
        assertEq(harness.exposedAbsolute(7), 7);
    }

    function testAbsoluteNegative() public view {
        assertEq(harness.exposedAbsolute(-7), 7);
    }

    function testAbsoluteIntMin() public view {
        uint256 expected = uint256(type(int256).max) + 1;
        assertEq(harness.exposedAbsolute(type(int256).min), expected);
    }
}
