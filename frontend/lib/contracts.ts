import "@kaiachain/ethers-ext"; // enable KAIA compat for ethers v6 (side-effect)
import { ethers } from "ethers";
import type { AppConfig } from "@/lib/appConfig";

// ABIs
export const ERC20 = [
  "function decimals() view returns (uint8)",
  "function balanceOf(address) view returns (uint256)",
  "function totalSupply() view returns (uint256)",
  "function allowance(address owner, address spender) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
  "function transfer(address to, uint256 amount) returns (bool)",
  "function symbol() view returns (string)",
  "function name() view returns (string)"
];

export const VaultABI = [
  "function deposit(uint256 amount) external",
  "function depositWithPermit2(address owner, address token, uint256 amount, uint256 sigDeadline, bytes permitSig) external",
  
  // --- Withdraw queue (try these in order) ---
  "function requestWithdrawal(uint256 amount) external",             // preferred
  "function queueWithdrawal(uint256 amount) external",               // alt
  "function requestRedeem(uint256 amount) external",                 // alt
  "function requestWithdraw(uint256 amount) external",               // alt spelling
  
  // --- Claim (try these in order) ---
  "function claimWithdrawal() external",                             // preferred
  "function claim() external",                                       // alt
  "function withdraw() external",                                    // alt
  "function claimRedeem() external",                                 // alt
  
  // --- Views (try these in order) ---
  "function pendingWithdrawal(address) view returns (uint256 amount, uint64 epoch)",
  "function getPendingWithdrawal(address) view returns (uint256 amount, uint64 epoch)",
  "function pendingNext(address) view returns (uint256)",
  "function claimable(address) view returns (uint256)",
  
  // Existing views
  "function totalStakedUSDT() view returns (uint256)",
  "function epochInfo() view returns (uint64 currentEpoch, uint64 nextRolloverAt)",
  
  // New epoch views for 10-day epochs
  "function epoch0Start() view returns (uint64)",
  "function epochDuration() view returns (uint64)",
  "function currentEpoch() view returns (uint64)",
  "function epochEnd(uint64 epoch) view returns (uint64)",
  "function timeUntilEpochEnd() view returns (uint256)",
  
  // Cumulative tracking views
  "function totalDepositedUSDT() view returns (uint256)",
  "function totalClaimedUSDT() view returns (uint256)",
  
  // Events for fallback scanning
  "event Deposit(address indexed owner, uint256 amount)",
  "event ClaimWithdrawal(address indexed owner, uint256 usdtAmount)"
];

export const StrategyABI = [
  "function totalUSDTEquivalent() view returns (uint256)", // strategy-side USDT equivalent
  "function totalSUSDe() view returns (uint256)",           // sUSDe balance (if available); else expose a view
  "function epochInfo() view returns (uint64 currentEpoch, uint64 nextRolloverAt)",
  "function totalAssets() view returns (uint256)",
  "function currentEpoch() view returns (uint256)",
  "function epochDuration() view returns (uint256)",
  "function queuedWithdrawalUSDT() view returns (uint256)"
];

// Permit2 (AllowanceTransfer) subset ABI
export const Permit2ABI = [
  "function DOMAIN_SEPARATOR() view returns (bytes32)",
  "function permit(address owner, ((address token,uint160 amount,uint48 expiration,uint48 nonce) details, address spender, uint256 sigDeadline) single, bytes signature)",
  "function transferFrom((address from, address to, uint160 amount, address token)[] transferDetails) external"
];

// Provider factories
export function makeKaiaProvider(cfg: AppConfig) {
  if (!cfg.kaiaRpc) {
    throw new Error("KAIA RPC URL not configured");
  }
  return new ethers.JsonRpcProvider(cfg.kaiaRpc);
}

export function makeEthProvider(cfg: AppConfig) {
  if (!cfg.ethRpc) {
    // Return null provider if ETH not configured (optional chain)
    return null;
  }
  return new ethers.JsonRpcProvider(cfg.ethRpc);
}

// Address helper
export function addresses(cfg: AppConfig) {
  return {
    kaiaUSDT: cfg.usdt,
    rkUSDT: cfg.rkUSDT,
    vault: cfg.vault,
    permit2: cfg.permit2,
    strategy: cfg.ethStrategy || "",
    ethUSDT: "", // Can be added to config if needed
    ethSUSDe: "" // Can be added to config if needed
  };
}

// Contract factories
export function getVaultContract(cfg: AppConfig, signerOrProvider: ethers.Signer | ethers.Provider) {
  const addr = addresses(cfg);
  if (!addr.vault) throw new Error("Vault address not configured");
  return new ethers.Contract(addr.vault, VaultABI, signerOrProvider);
}

export function getUSDTContract(cfg: AppConfig, signerOrProvider: ethers.Signer | ethers.Provider) {
  const addr = addresses(cfg);
  if (!addr.kaiaUSDT) throw new Error("USDT address not configured");
  return new ethers.Contract(addr.kaiaUSDT, ERC20, signerOrProvider);
}

export function getRkUSDTContract(cfg: AppConfig, signerOrProvider: ethers.Signer | ethers.Provider) {
  const addr = addresses(cfg);
  if (!addr.rkUSDT) throw new Error("rkUSDT address not configured");
  return new ethers.Contract(addr.rkUSDT, ERC20, signerOrProvider);
}

export function getPermit2Contract(cfg: AppConfig, signerOrProvider: ethers.Signer | ethers.Provider) {
  const addr = addresses(cfg);
  if (!addr.permit2) throw new Error("Permit2 address not configured");
  return new ethers.Contract(addr.permit2, Permit2ABI, signerOrProvider);
}

export function getStrategyContract(cfg: AppConfig, signerOrProvider: ethers.Signer | ethers.Provider) {
  const addr = addresses(cfg);
  if (!addr.strategy) return null; // Strategy is optional
  return new ethers.Contract(addr.strategy, StrategyABI, signerOrProvider);
}

// Legacy compatibility exports (deprecated - use config-based functions above)
export const PERMIT2_ADDR = process.env.NEXT_PUBLIC_KAIA_PERMIT2 || "0x000000000022d473030f116ddee9f6b43ac78ba3";

export const rpc = {
  kaia: process.env.NEXT_PUBLIC_KAIA_RPC_URL || "https://public-en-kairos.node.kaia.io",
  eth: process.env.NEXT_PUBLIC_ETH_RPC_URL || ""
};

export const addr = {
  kaiaUSDT: process.env.NEXT_PUBLIC_KAIA_USDT || "",
  rkUSDT: process.env.NEXT_PUBLIC_KAIA_RKUSDT || "",
  vault: process.env.NEXT_PUBLIC_KAIA_VAULT || "",
  strategy: process.env.NEXT_PUBLIC_ETH_STRATEGY || "",
  ethUSDT: process.env.NEXT_PUBLIC_ETH_USDT || "",
  ethSUSDe: process.env.NEXT_PUBLIC_ETH_SUSDE || ""
};

export function kaiaProvider() { return new ethers.JsonRpcProvider(rpc.kaia); }
export function ethProvider() { return rpc.eth ? new ethers.JsonRpcProvider(rpc.eth) : null; }