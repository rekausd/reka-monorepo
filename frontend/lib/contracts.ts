import "@kaiachain/ethers-ext"; // enable KAIA compat for ethers v6 (side-effect)
import { ethers } from "ethers";

export const rpc = {
  kaia: process.env.NEXT_PUBLIC_KAIA_RPC_URL!,
  eth:  process.env.NEXT_PUBLIC_ETH_RPC_URL!
};

export const addr = {
  kaiaUSDT:  process.env.NEXT_PUBLIC_KAIA_USDT!,
  rkUSDT:    process.env.NEXT_PUBLIC_KAIA_RKUSDT!,
  vault:     process.env.NEXT_PUBLIC_KAIA_VAULT!,
  strategy:  process.env.NEXT_PUBLIC_ETH_STRATEGY!,
  ethUSDT:   process.env.NEXT_PUBLIC_ETH_USDT || "",
  ethSUSDe:  process.env.NEXT_PUBLIC_ETH_SUSDE || ""
};

// Minimal ABIs
export const ERC20 = [
  "function decimals() view returns (uint8)",
  "function balanceOf(address) view returns (uint256)",
  "function totalSupply() view returns (uint256)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)"
];

export const VaultABI = [
  "function deposit(uint256 amount) external",
  "function totalStakedUSDT() view returns (uint256)",   // if not available, derive via accounting or expose in your contract
  "function epochInfo() view returns (uint64 currentEpoch, uint64 nextRolloverAt)"
];

export const StrategyABI = [
  "function totalUSDTEquivalent() view returns (uint256)", // strategy-side USDT equivalent
  "function totalSUSDe() view returns (uint256)",           // sUSDe balance (if available); else expose a view
  "function epochInfo() view returns (uint64 currentEpoch, uint64 nextRolloverAt)"
];

export function kaiaProvider(){ return new ethers.JsonRpcProvider(rpc.kaia); }
export function ethProvider(){ return new ethers.JsonRpcProvider(rpc.eth); }