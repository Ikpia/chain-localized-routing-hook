import { useMemo, useState } from "react";
import { BrowserProvider, Contract } from "ethers";

import registryAbi from "@shared/abi/RoutingPolicyRegistry.json";
import { CHAIN_IDS, PROFILE_LABELS, type ChainProfile } from "@shared/constants/chains";

const PROFILE_TO_ENUM: Record<ChainProfile, number> = {
  BASE: 1,
  OPTIMISM: 2,
  ARBITRUM: 3,
};

type PolicyForm = {
  enabled: boolean;
  maxAmountIn: string;
  maxPriceImpactBps: string;
  cooldownSeconds: string;
  maxSwapsPerBlock: string;
  enforceRouterAllowlist: boolean;
  enforceActorDenylist: boolean;
  dynamicFeeEnabled: boolean;
  baseFee: string;
  gasPriceCeilingWei: string;
};

declare global {
  interface Window {
    ethereum?: unknown;
  }
}

function App() {
  const [account, setAccount] = useState<string>("");
  const [activeChainId, setActiveChainId] = useState<number>(CHAIN_IDS.LOCAL_ANVIL);
  const [registryAddress, setRegistryAddress] = useState<string>("");
  const [poolId, setPoolId] = useState<string>("");
  const [profile, setProfile] = useState<ChainProfile>("BASE");

  const [routerAddress, setRouterAddress] = useState<string>("");
  const [actorAddress, setActorAddress] = useState<string>("");

  const [policy, setPolicy] = useState<PolicyForm>({
    enabled: true,
    maxAmountIn: "1000000000000000000",
    maxPriceImpactBps: "1000",
    cooldownSeconds: "0",
    maxSwapsPerBlock: "20",
    enforceRouterAllowlist: false,
    enforceActorDenylist: false,
    dynamicFeeEnabled: false,
    baseFee: "3000",
    gasPriceCeilingWei: "0",
  });

  const [status, setStatus] = useState<string[]>([]);

  const chainTargets = useMemo(
    () => [
      { label: "Base Sepolia", chainId: CHAIN_IDS.BASE_SEPOLIA },
      { label: "Optimism Sepolia", chainId: CHAIN_IDS.OPTIMISM_SEPOLIA },
      { label: "Arbitrum Sepolia", chainId: CHAIN_IDS.ARBITRUM_SEPOLIA },
      { label: "Local Anvil", chainId: CHAIN_IDS.LOCAL_ANVIL },
    ],
    []
  );

  const addStatus = (line: string) => {
    setStatus((prev) => [line, ...prev].slice(0, 12));
  };

  const connectWallet = async () => {
    if (!window.ethereum) {
      addStatus("Wallet not found. Install MetaMask or a compatible EIP-1193 wallet.");
      return;
    }

    const provider = new BrowserProvider(window.ethereum as any);
    const signer = await provider.getSigner();
    const connectedAccount = await signer.getAddress();
    const network = await provider.getNetwork();

    setAccount(connectedAccount);
    setActiveChainId(Number(network.chainId));
    addStatus(`Connected ${connectedAccount} on chain ${network.chainId.toString()}.`);
  };

  const getRegistry = async () => {
    if (!window.ethereum) {
      throw new Error("Wallet not found.");
    }
    if (!registryAddress) {
      throw new Error("Registry address is required.");
    }

    const provider = new BrowserProvider(window.ethereum as any);
    const signer = await provider.getSigner();
    return new Contract(registryAddress, registryAbi, signer);
  };

  const setChainProfile = async () => {
    try {
      const registry = await getRegistry();
      const tx = await registry.setChainProfile(activeChainId, PROFILE_TO_ENUM[profile]);
      addStatus(`setChainProfile tx sent: ${tx.hash}`);
      await tx.wait();
      addStatus(`Chain profile set to ${PROFILE_LABELS[profile]} on ${activeChainId}.`);
    } catch (error) {
      addStatus(`setChainProfile failed: ${(error as Error).message}`);
    }
  };

  const setPoolPolicy = async () => {
    try {
      if (!poolId) {
        throw new Error("PoolId is required.");
      }

      const registry = await getRegistry();
      const policyTuple = [
        policy.enabled,
        BigInt(policy.maxAmountIn),
        Number(policy.maxPriceImpactBps),
        Number(policy.cooldownSeconds),
        Number(policy.maxSwapsPerBlock),
        policy.enforceRouterAllowlist,
        policy.enforceActorDenylist,
        policy.dynamicFeeEnabled,
        Number(policy.baseFee),
        BigInt(policy.gasPriceCeilingWei),
      ];

      const tx = await registry.setPoolPolicy(activeChainId, poolId, policyTuple);
      addStatus(`setPoolPolicy tx sent: ${tx.hash}`);
      await tx.wait();
      addStatus("Pool policy applied.");
    } catch (error) {
      addStatus(`setPoolPolicy failed: ${(error as Error).message}`);
    }
  };

  const setRouterAllowlist = async (allowed: boolean) => {
    try {
      if (!poolId || !routerAddress) {
        throw new Error("PoolId and router address are required.");
      }

      const registry = await getRegistry();
      const tx = await registry.setRouterAllowlist(activeChainId, poolId, routerAddress, allowed);
      addStatus(`setRouterAllowlist tx sent: ${tx.hash}`);
      await tx.wait();
      addStatus(`Router ${allowed ? "allowlisted" : "removed from allowlist"}.`);
    } catch (error) {
      addStatus(`setRouterAllowlist failed: ${(error as Error).message}`);
    }
  };

  const setActorDenylist = async (denied: boolean) => {
    try {
      if (!poolId || !actorAddress) {
        throw new Error("PoolId and actor address are required.");
      }

      const registry = await getRegistry();
      const tx = await registry.setActorDenylist(activeChainId, poolId, actorAddress, denied);
      addStatus(`setActorDenylist tx sent: ${tx.hash}`);
      await tx.wait();
      addStatus(`Actor ${denied ? "denylisted" : "removed from denylist"}.`);
    } catch (error) {
      addStatus(`setActorDenylist failed: ${(error as Error).message}`);
    }
  };

  const deploymentCommand = `RPC_URL=<rpc> PRIVATE_KEY=<key> make demo-testnet`;
  const poolInitCommand = `forge script script/01_CreatePoolAndAddLiquidity.s.sol --rpc-url <rpc> --broadcast`;

  return (
    <main className="page">
      <section className="hero">
        <p className="eyebrow">Chain-Localized Routing Hook</p>
        <h1>Chain-Aware Execution Dashboard</h1>
        <p>
          Configure Base / Optimism / Arbitrum policy profiles, push policy updates on-chain, and run localized routing
          experiments without external routers.
        </p>
      </section>

      <section className="grid">
        <article className="card">
          <h2>1. Connection</h2>
          <button onClick={connectWallet} className="primary">Connect Wallet</button>
          <p>Account: {account || "not connected"}</p>
          <p>Active chainId: {activeChainId}</p>
          <label>
            Target chain
            <select value={activeChainId} onChange={(e) => setActiveChainId(Number(e.target.value))}>
              {chainTargets.map((item) => (
                <option key={item.chainId} value={item.chainId}>
                  {item.label} ({item.chainId})
                </option>
              ))}
            </select>
          </label>
        </article>

        <article className="card">
          <h2>2. Registry + Pool Inputs</h2>
          <label>
            RoutingPolicyRegistry
            <input
              value={registryAddress}
              onChange={(e) => setRegistryAddress(e.target.value)}
              placeholder="0x..."
            />
          </label>
          <label>
            PoolId (bytes32)
            <input value={poolId} onChange={(e) => setPoolId(e.target.value)} placeholder="0x..." />
          </label>
          <label>
            Chain profile
            <select value={profile} onChange={(e) => setProfile(e.target.value as ChainProfile)}>
              <option value="BASE">Base</option>
              <option value="OPTIMISM">Optimism</option>
              <option value="ARBITRUM">Arbitrum</option>
            </select>
          </label>
          <button onClick={setChainProfile}>Set Chain Profile</button>
        </article>

        <article className="card wide">
          <h2>3. Pool Policy</h2>
          <div className="form-grid">
            <label>
              maxAmountIn (wei)
              <input value={policy.maxAmountIn} onChange={(e) => setPolicy({ ...policy, maxAmountIn: e.target.value })} />
            </label>
            <label>
              maxPriceImpactBps
              <input
                value={policy.maxPriceImpactBps}
                onChange={(e) => setPolicy({ ...policy, maxPriceImpactBps: e.target.value })}
              />
            </label>
            <label>
              cooldownSeconds
              <input
                value={policy.cooldownSeconds}
                onChange={(e) => setPolicy({ ...policy, cooldownSeconds: e.target.value })}
              />
            </label>
            <label>
              maxSwapsPerBlock
              <input
                value={policy.maxSwapsPerBlock}
                onChange={(e) => setPolicy({ ...policy, maxSwapsPerBlock: e.target.value })}
              />
            </label>
            <label>
              baseFee (hundredths of a bip)
              <input value={policy.baseFee} onChange={(e) => setPolicy({ ...policy, baseFee: e.target.value })} />
            </label>
            <label>
              gasPriceCeilingWei
              <input
                value={policy.gasPriceCeilingWei}
                onChange={(e) => setPolicy({ ...policy, gasPriceCeilingWei: e.target.value })}
              />
            </label>
          </div>

          <div className="switches">
            <label>
              <input
                type="checkbox"
                checked={policy.enabled}
                onChange={(e) => setPolicy({ ...policy, enabled: e.target.checked })}
              />
              Enabled
            </label>
            <label>
              <input
                type="checkbox"
                checked={policy.enforceRouterAllowlist}
                onChange={(e) => setPolicy({ ...policy, enforceRouterAllowlist: e.target.checked })}
              />
              Enforce Router Allowlist
            </label>
            <label>
              <input
                type="checkbox"
                checked={policy.enforceActorDenylist}
                onChange={(e) => setPolicy({ ...policy, enforceActorDenylist: e.target.checked })}
              />
              Enforce Actor Denylist
            </label>
            <label>
              <input
                type="checkbox"
                checked={policy.dynamicFeeEnabled}
                onChange={(e) => setPolicy({ ...policy, dynamicFeeEnabled: e.target.checked })}
              />
              Dynamic Fee Override
            </label>
          </div>

          <button className="primary" onClick={setPoolPolicy}>Set Pool Policy</button>
        </article>

        <article className="card">
          <h2>4. Allowlist / Denylist</h2>
          <label>
            Router address
            <input value={routerAddress} onChange={(e) => setRouterAddress(e.target.value)} placeholder="0x..." />
          </label>
          <div className="row">
            <button onClick={() => setRouterAllowlist(true)}>Allow Router</button>
            <button onClick={() => setRouterAllowlist(false)}>Remove Router</button>
          </div>

          <label>
            Actor address
            <input value={actorAddress} onChange={(e) => setActorAddress(e.target.value)} placeholder="0x..." />
          </label>
          <div className="row">
            <button onClick={() => setActorDenylist(true)}>Deny Actor</button>
            <button onClick={() => setActorDenylist(false)}>Undeny Actor</button>
          </div>
        </article>

        <article className="card">
          <h2>5. Deploy + Init Helpers</h2>
          <p>Deploy hook + registry:</p>
          <code>{deploymentCommand}</code>
          <p>Initialize pool + seed liquidity:</p>
          <code>{poolInitCommand}</code>
          <p>Profile demo:</p>
          <code>make demo-profiles</code>
        </article>

        <article className="card wide">
          <h2>Recent Actions</h2>
          <ul>
            {status.map((line) => (
              <li key={line}>{line}</li>
            ))}
          </ul>
        </article>
      </section>
    </main>
  );
}

export default App;
