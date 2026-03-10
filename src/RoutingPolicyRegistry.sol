// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IRoutingPolicyRegistry} from "src/interfaces/IRoutingPolicyRegistry.sol";
import {PolicyTypes} from "src/libraries/PolicyTypes.sol";
import {FeePolicyModule} from "src/modules/FeePolicyModule.sol";
import {LimitsModule} from "src/modules/LimitsModule.sol";

contract RoutingPolicyRegistry is IRoutingPolicyRegistry {
    uint256 public constant MAX_COOLDOWN_SECONDS = 1 days;
    uint24 public constant MAX_PRICE_IMPACT_BPS = 10_000;
    uint16 public constant MAX_SWAPS_PER_BLOCK = 1_000;

    error NotOwner();
    error ZeroAddress();
    error InvalidPolicy();
    error UnauthorizedHook();

    event OwnerTransferred(address indexed previousOwner, address indexed newOwner);
    event ChainProfileSet(uint256 indexed chainId, PolicyTypes.ChainProfile profile);
    event HookAuthorizationUpdated(address indexed hook, bool authorized);
    event ActorDenylistUpdated(uint256 indexed chainId, bytes32 indexed poolId, address indexed actor, bool denied);
    event RouterAllowlistUpdatedForPool(
        uint256 indexed chainId,
        bytes32 indexed poolId,
        address indexed router,
        bool allowed
    );

    address public owner;

    mapping(address hook => bool authorized) public isAuthorizedHook;
    mapping(uint256 chainId => PolicyTypes.ChainProfile profile) private _chainProfiles;
    mapping(uint256 chainId => mapping(bytes32 poolId => PolicyTypes.PoolPolicy policy)) private _poolPolicies;
    mapping(uint256 chainId => mapping(bytes32 poolId => mapping(address router => bool allowed))) private _routerAllowlist;
    mapping(uint256 chainId => mapping(bytes32 poolId => mapping(address actor => bool denied))) private _actorDenylist;

    mapping(uint256 chainId => mapping(bytes32 poolId => uint256 timestamp)) public lastSwapAt;
    mapping(uint256 chainId => mapping(bytes32 poolId => mapping(uint256 blockNumber => uint256 count))) public swapsPerBlock;

    uint256 private _lock;

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyAuthorizedHook() {
        if (!isAuthorizedHook[msg.sender]) revert UnauthorizedHook();
        _;
    }

    modifier nonReentrant() {
        if (_lock == 1) revert UnauthorizedHook();
        _lock = 1;
        _;
        _lock = 0;
    }

    constructor(address initialOwner) {
        if (initialOwner == address(0)) revert ZeroAddress();
        owner = initialOwner;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnerTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setHookAuthorization(address hook, bool authorized) external onlyOwner {
        if (hook == address(0)) revert ZeroAddress();
        isAuthorizedHook[hook] = authorized;
        emit HookAuthorizationUpdated(hook, authorized);
    }

    function setChainProfile(uint256 chainId, PolicyTypes.ChainProfile profile) external onlyOwner {
        _chainProfiles[chainId] = profile;
        emit ChainProfileSet(chainId, profile);
    }

    function getChainProfile(uint256 chainId) external view returns (PolicyTypes.ChainProfile) {
        return _chainProfiles[chainId];
    }

    function getPoolPolicy(uint256 chainId, bytes32 poolId) external view returns (PolicyTypes.PoolPolicy memory) {
        return _poolPolicies[chainId][poolId];
    }

    function isRouterAllowed(uint256 chainId, bytes32 poolId, address router) external view returns (bool) {
        return _routerAllowlist[chainId][poolId][router];
    }

    function isActorDenied(uint256 chainId, bytes32 poolId, address actor) external view returns (bool) {
        return _actorDenylist[chainId][poolId][actor];
    }

    function setPoolPolicy(uint256 chainId, bytes32 poolId, PolicyTypes.PoolPolicy calldata policy) external onlyOwner {
        _validatePolicy(policy);
        _poolPolicies[chainId][poolId] = policy;

        emit PolicySet(chainId, poolId, keccak256(abi.encode(policy)));
    }

    function setRouterAllowlist(uint256 chainId, bytes32 poolId, address router, bool allowed) external onlyOwner {
        if (router == address(0)) revert ZeroAddress();

        _routerAllowlist[chainId][poolId][router] = allowed;
        emit RouterAllowlistUpdated(chainId, router, allowed);
        emit RouterAllowlistUpdatedForPool(chainId, poolId, router, allowed);
    }

    function setActorDenylist(uint256 chainId, bytes32 poolId, address actor, bool denied) external onlyOwner {
        if (actor == address(0)) revert ZeroAddress();

        _actorDenylist[chainId][poolId][actor] = denied;
        emit ActorDenylistUpdated(chainId, poolId, actor, denied);
    }

    function seedDefaultPolicy(uint256 chainId, bytes32 poolId, uint128 liquidityReference) external onlyOwner {
        PolicyTypes.ChainProfile profile = _chainProfiles[chainId];

        PolicyTypes.PoolPolicy memory policy;
        policy.enabled = true;
        policy.maxPriceImpactBps = 2_000;
        policy.maxAmountIn = _maxAmountByProfile(profile, liquidityReference);

        if (profile == PolicyTypes.ChainProfile.BASE) {
            policy.cooldownSeconds = 0;
            policy.maxSwapsPerBlock = 20;
            policy.dynamicFeeEnabled = false;
            policy.baseFee = 2_500;
            policy.gasPriceCeilingWei = 5 gwei;
        } else if (profile == PolicyTypes.ChainProfile.OPTIMISM) {
            policy.cooldownSeconds = 2;
            policy.maxSwapsPerBlock = 8;
            policy.maxPriceImpactBps = 800;
            policy.dynamicFeeEnabled = true;
            policy.baseFee = 3_000;
            policy.gasPriceCeilingWei = 2 gwei;
        } else if (profile == PolicyTypes.ChainProfile.ARBITRUM) {
            policy.cooldownSeconds = 1;
            policy.maxSwapsPerBlock = 12;
            policy.maxPriceImpactBps = 1_500;
            policy.dynamicFeeEnabled = true;
            policy.baseFee = 3_500;
            policy.gasPriceCeilingWei = 1 gwei;
            policy.enforceRouterAllowlist = true;
        } else {
            policy.cooldownSeconds = 1;
            policy.maxSwapsPerBlock = 10;
            policy.baseFee = 3_000;
            policy.gasPriceCeilingWei = 3 gwei;
        }

        _validatePolicy(policy);
        _poolPolicies[chainId][poolId] = policy;

        emit PolicySet(chainId, poolId, keccak256(abi.encode(policy)));
    }

    function validateAndRecordSwap(PolicyTypes.SwapContext calldata context)
        external
        onlyAuthorizedHook
        nonReentrant
        returns (PolicyTypes.PolicyDecision memory decision)
    {
        PolicyTypes.PoolPolicy memory policy = _poolPolicies[context.chainId][context.poolId];

        if (!policy.enabled) {
            decision = PolicyTypes.PolicyDecision({
                allowed: true,
                reasonCode: uint8(PolicyTypes.ReasonCode.POLICY_DISABLED),
                feeOverride: 0
            });
            emit SwapAllowed(context.chainId, context.poolId, context.trader, decision.reasonCode);
            return decision;
        }

        if (policy.enforceActorDenylist && _actorDenylist[context.chainId][context.poolId][context.trader]) {
            return _blocked(context, PolicyTypes.ReasonCode.ACTOR_DENIED);
        }

        if (policy.enforceRouterAllowlist && !_routerAllowlist[context.chainId][context.poolId][context.router]) {
            return _blocked(context, PolicyTypes.ReasonCode.ROUTER_NOT_ALLOWLISTED);
        }

        if (policy.maxAmountIn > 0 && context.amountIn > policy.maxAmountIn) {
            return _blocked(context, PolicyTypes.ReasonCode.SWAP_TOO_LARGE);
        }

        if (policy.gasPriceCeilingWei > 0 && context.gasPriceWei > policy.gasPriceCeilingWei) {
            return _blocked(context, PolicyTypes.ReasonCode.GAS_PRICE_TOO_HIGH);
        }

        if (policy.maxPriceImpactBps > 0) {
            uint24 estimatedImpact = LimitsModule.approximatePriceImpactBps(context.sqrtPriceX96, context.sqrtPriceLimitX96);
            if (estimatedImpact > policy.maxPriceImpactBps) {
                return _blocked(context, PolicyTypes.ReasonCode.PRICE_IMPACT_TOO_HIGH);
            }
        }

        if (policy.cooldownSeconds > 0) {
            uint256 last = lastSwapAt[context.chainId][context.poolId];
            if (last > 0 && block.timestamp < last + policy.cooldownSeconds) {
                return _blocked(context, PolicyTypes.ReasonCode.COOLDOWN_ACTIVE);
            }
        }

        if (policy.maxSwapsPerBlock > 0) {
            uint256 currentCount = swapsPerBlock[context.chainId][context.poolId][block.number];
            if (currentCount >= policy.maxSwapsPerBlock) {
                return _blocked(context, PolicyTypes.ReasonCode.SWAPS_PER_BLOCK_EXCEEDED);
            }
            swapsPerBlock[context.chainId][context.poolId][block.number] = currentCount + 1;
        }

        lastSwapAt[context.chainId][context.poolId] = block.timestamp;

        decision = PolicyTypes.PolicyDecision({
            allowed: true,
            reasonCode: uint8(PolicyTypes.ReasonCode.ALLOWED),
            feeOverride: FeePolicyModule.computeFeeOverride(_chainProfiles[context.chainId], policy, context.gasPriceWei)
        });

        emit SwapAllowed(context.chainId, context.poolId, context.trader, decision.reasonCode);
    }

    function _blocked(PolicyTypes.SwapContext calldata context, PolicyTypes.ReasonCode reason)
        private
        returns (PolicyTypes.PolicyDecision memory decision)
    {
        decision = PolicyTypes.PolicyDecision({allowed: false, reasonCode: uint8(reason), feeOverride: 0});
        emit SwapBlocked(context.chainId, context.poolId, context.trader, decision.reasonCode);
    }

    function _validatePolicy(PolicyTypes.PoolPolicy memory policy) private pure {
        if (policy.maxPriceImpactBps > MAX_PRICE_IMPACT_BPS) revert InvalidPolicy();
        if (policy.cooldownSeconds > MAX_COOLDOWN_SECONDS) revert InvalidPolicy();
        if (policy.maxSwapsPerBlock > MAX_SWAPS_PER_BLOCK) revert InvalidPolicy();
    }

    function _maxAmountByProfile(PolicyTypes.ChainProfile profile, uint128 liquidityReference)
        private
        pure
        returns (uint128)
    {
        if (liquidityReference == 0) {
            return 0;
        }

        if (profile == PolicyTypes.ChainProfile.BASE) {
            return liquidityReference / 2;
        }
        if (profile == PolicyTypes.ChainProfile.OPTIMISM) {
            return liquidityReference / 5;
        }
        if (profile == PolicyTypes.ChainProfile.ARBITRUM) {
            return liquidityReference / 3;
        }

        return liquidityReference / 4;
    }
}
