export type YieldSource = { name: string; apyBps: number; url?: string };

export type AppConfig = {
  kaiaRpc: string;
  permit2: string;
  usdt: string;
  rkUSDT: string;
  vault: string;
  ethRpc?: string;
  ethStrategy?: string;
  faucetToken?: string;
  faucetAmount?: string;
  kaiaStartBlock?: number;
  strategyApyBps?: number;          // e.g. 1100 = 11.00%
  yieldSources?: YieldSource[];
};

// Fallback to NEXT_PUBLIC_* if config file is missing (local dev)
export function envFallback(): AppConfig {
  return {
    kaiaRpc: process.env.NEXT_PUBLIC_KAIA_RPC_URL || "https://public-en-kairos.node.kaia.io",
    permit2: process.env.NEXT_PUBLIC_KAIA_PERMIT2 || "0x000000000022d473030f116ddee9f6b43ac78ba3",
    usdt: process.env.NEXT_PUBLIC_KAIA_USDT || "",
    rkUSDT: process.env.NEXT_PUBLIC_KAIA_RKUSDT || "",
    vault: process.env.NEXT_PUBLIC_KAIA_VAULT || "",
    ethRpc: process.env.NEXT_PUBLIC_ETH_RPC_URL || "",
    ethStrategy: process.env.NEXT_PUBLIC_ETH_STRATEGY || "",
    faucetToken: process.env.NEXT_PUBLIC_KAIA_USDT || "",
    faucetAmount: "10000"
  };
}