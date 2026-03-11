// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";

import {IUniswapV4Router04} from "hookmate/interfaces/router/IUniswapV4Router04.sol";

import {Deployers} from "test/utils/Deployers.sol";

/// @notice Shared configuration between scripts
contract BaseScript is Script, Deployers {
    address immutable deployerAddress;

    IERC20 internal immutable token0;
    IERC20 internal immutable token1;
    IHooks internal immutable hookContract;
    Currency internal immutable currency0;
    Currency internal immutable currency1;

    constructor() {
        // Make sure artifacts are available, either deploy or configure.
        deployArtifacts();

        deployerAddress = getDeployer();

        address token0Address = vm.envAddress("TOKEN0");
        address token1Address = vm.envAddress("TOKEN1");
        address hookAddress = vm.envOr("HOOK_ADDRESS", address(0));

        token0 = IERC20(token0Address);
        token1 = IERC20(token1Address);
        hookContract = IHooks(hookAddress);

        (currency0, currency1) = getCurrencies();

        vm.label(address(permit2), "Permit2");
        vm.label(address(poolManager), "V4PoolManager");
        vm.label(address(positionManager), "V4PositionManager");
        vm.label(address(swapRouter), "V4SwapRouter");

        vm.label(address(token0), "Currency0");
        vm.label(address(token1), "Currency1");

        vm.label(address(hookContract), "HookContract");
    }

    function _etch(address target, bytes memory bytecode) internal override {
        if (block.chainid == 31337) {
            vm.rpc("anvil_setCode", string.concat('["', vm.toString(target), '",', '"', vm.toString(bytecode), '"]'));
        } else {
            revert("Unsupported etch on this network");
        }
    }

    function deployPoolManager() internal virtual override {
        if (block.chainid == 31337) {
            super.deployPoolManager();
            return;
        }

        address configured = _resolveConfiguredAddress("POOL_MANAGER_ADDRESS");
        if (configured != address(0)) {
            poolManager = IPoolManager(configured);
            return;
        }

        super.deployPoolManager();
    }

    function deployPositionManager() internal virtual override {
        if (block.chainid == 31337) {
            super.deployPositionManager();
            return;
        }

        address configured = _resolveConfiguredAddress("POSITION_MANAGER_ADDRESS");
        if (configured != address(0)) {
            positionManager = IPositionManager(configured);
            return;
        }

        super.deployPositionManager();
    }

    function deployRouter() internal virtual override {
        if (block.chainid == 31337) {
            super.deployRouter();
            return;
        }

        address configured = _resolveConfiguredAddress("UNIVERSAL_ROUTER_ADDRESS");
        if (configured != address(0)) {
            swapRouter = IUniswapV4Router04(payable(configured));
            return;
        }

        super.deployRouter();
    }

    function _resolveConfiguredAddress(string memory suffix) internal view returns (address) {
        (address configured, bool isChainScoped) = _getConfiguredAddress(suffix);
        if (configured == address(0)) {
            return address(0);
        }

        if (configured.code.length > 0) {
            return configured;
        }

        if (isChainScoped) {
            revert(string.concat(_chainScopedKey(suffix), " has no code"));
        }

        // Ignore generic config if it does not exist on the active chain.
        return address(0);
    }

    function _getConfiguredAddress(string memory suffix) internal view returns (address configured, bool isChainScoped) {
        string memory prefix = _chainEnvPrefix();

        if (bytes(prefix).length > 0) {
            string memory chainScoped = string.concat(prefix, "_", suffix);
            configured = vm.envOr(chainScoped, address(0));
            if (configured != address(0)) {
                return (configured, true);
            }
        }

        configured = vm.envOr(suffix, address(0));
        return (configured, false);
    }

    function _chainScopedKey(string memory suffix) internal view returns (string memory) {
        string memory prefix = _chainEnvPrefix();
        if (bytes(prefix).length == 0) {
            return suffix;
        }
        return string.concat(prefix, "_", suffix);
    }

    function _chainEnvPrefix() internal view returns (string memory) {
        if (block.chainid == 130) return "UNICHAIN";
        if (block.chainid == 10) return "OPTIMISM";
        if (block.chainid == 8453) return "BASE";
        if (block.chainid == 42161) return "ARBITRUM";
        if (block.chainid == 1301) return "UNICHAIN_SEPOLIA";
        if (block.chainid == 84532) return "BASE_SEPOLIA";
        if (block.chainid == 11155420) return "OPTIMISM_SEPOLIA";
        if (block.chainid == 421614) return "ARBITRUM_SEPOLIA";
        if (block.chainid == 11155111) return "SEPOLIA";
        return "";
    }

    function getCurrencies() internal view returns (Currency, Currency) {
        require(address(token0) != address(token1));

        if (token0 < token1) {
            return (Currency.wrap(address(token0)), Currency.wrap(address(token1)));
        } else {
            return (Currency.wrap(address(token1)), Currency.wrap(address(token0)));
        }
    }

    function getDeployer() internal returns (address) {
        address[] memory wallets = vm.getWallets();

        if (wallets.length > 0) {
            return wallets[0];
        } else {
            return msg.sender;
        }
    }
}
