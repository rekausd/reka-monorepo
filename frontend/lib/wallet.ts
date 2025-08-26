import "@kaiachain/ethers-ext";
import { ethers } from "ethers";

export function detectInjectedKaia(): any | null {
  if (typeof window === "undefined") return null;
  const w = window as any;
  return w.kaia ?? w.klaytn ?? null;
}

export async function connectKaiaWallet(){
  const inj = detectInjectedKaia();
  if (!inj) throw new Error("KAIA Wallet not found. Install KAIA Wallet.");
  const provider = new ethers.BrowserProvider(inj as any, "any"); // ethers-ext patches KAIA compat
  const accounts = await provider.send("eth_requestAccounts", []);
  const address = String(accounts?.[0] ?? "");
  const net = await provider.getNetwork();
  return { address, chainId: Number(net.chainId), provider };
}