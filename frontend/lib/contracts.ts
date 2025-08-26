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

export const PERMIT2_ADDR = process.env.NEXT_PUBLIC_KAIA_PERMIT2!;

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
  "function epochInfo() view returns (uint64 currentEpoch, uint64 nextRolloverAt)"
];

export const StrategyABI = [
  "function totalUSDTEquivalent() view returns (uint256)", // strategy-side USDT equivalent
  "function totalSUSDe() view returns (uint256)",           // sUSDe balance (if available); else expose a view
  "function epochInfo() view returns (uint64 currentEpoch, uint64 nextRolloverAt)"
];

// Permit2 (AllowanceTransfer) subset ABI
export const Permit2ABI = [
  "function DOMAIN_SEPARATOR() view returns (bytes32)",
  "function permit(address owner, (address token, uint160 amount, uint48 expiration, uint48 nonce) details, address spender, uint256 sigDeadline, bytes signature) external",
  "function transferFrom((address from, address to, uint160 amount, address token)[] transferDetails) external"
];

export function kaiaProvider(){ return new ethers.JsonRpcProvider(rpc.kaia); }
export function ethProvider(){ return new ethers.JsonRpcProvider(rpc.eth); }