import { ethers } from "ethers";

export const VaultABI = [
  "function epochInfo() view returns (uint64 currentEpoch, uint64 nextRolloverAt)",
  "function canRollover() view returns (bool)"
];

export const StrategyABI = [
  "function epochInfo() view returns (uint64 currentEpoch, uint64 nextRolloverAt)",
  "function canRollover() view returns (bool)",
  "function totalUSDTEquivalent() view returns (uint256)",
  "function queuedWithdrawalUSDT() view returns (uint256)",
  "function slippageBps() view returns (uint256)",
  "function kaiaRecipient() view returns (address)"
];

export const MetaSwapABI = [
  "function quoteUSDTtoUSDe(uint256 usdtIn) view returns (uint256)",
  "function quoteUSDetoUSDT(uint256 usdeIn) view returns (uint256)"
];

export const rpc = {
  kaia: process.env.NEXT_PUBLIC_KAIA_RPC_URL!,
  eth:  process.env.NEXT_PUBLIC_ETH_RPC_URL!
};

export const addr = {
  vault:    process.env.NEXT_PUBLIC_KAIA_VAULT!,
  strategy: process.env.NEXT_PUBLIC_ETH_STRATEGY!,
  metaSwap: process.env.NEXT_PUBLIC_META_SWAP!
};

// Read-only providers from RPCs (wallets handled separately)
export function prov(chain: "kaia"|"eth"){
  const url = chain === "kaia" ? rpc.kaia : rpc.eth;
  return new ethers.JsonRpcProvider(url);
}
