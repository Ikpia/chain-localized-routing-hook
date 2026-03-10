export type ChainProfile = "BASE" | "OPTIMISM" | "ARBITRUM";

export const CHAIN_IDS = {
  BASE_SEPOLIA: 84532,
  OPTIMISM_SEPOLIA: 11155420,
  ARBITRUM_SEPOLIA: 421614,
  LOCAL_ANVIL: 31337,
} as const;

export const PROFILE_LABELS: Record<ChainProfile, string> = {
  BASE: "Base",
  OPTIMISM: "Optimism",
  ARBITRUM: "Arbitrum",
};

export const EXPLORER_BY_CHAIN_ID: Record<number, string> = {
  [CHAIN_IDS.BASE_SEPOLIA]: "https://sepolia.basescan.org/tx/",
  [CHAIN_IDS.OPTIMISM_SEPOLIA]: "https://sepolia-optimism.etherscan.io/tx/",
  [CHAIN_IDS.ARBITRUM_SEPOLIA]: "https://sepolia.arbiscan.io/tx/",
};
