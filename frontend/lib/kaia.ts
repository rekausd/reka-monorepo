import { ethers } from "ethers";

export type KaiaConnection =
  | { kind: "KAIA_WALLET"; address: string; chainId: number; provider: ethers.BrowserProvider }
  | { kind: "KLIP"; address: string; chainId: number; provider: null };

export function detectInjectedKaia(): any | null {
  if (typeof window === "undefined") return null;
  const w = window as any;
  return w?.kaia ?? w?.klaytn ?? null;
}

export async function connectKaiaWallet(): Promise<KaiaConnection> {
  const inj = detectInjectedKaia();
  if (!inj) throw new Error("KAIA Wallet not found. Install KAIA Wallet extension.");

  const provider = new ethers.BrowserProvider(inj as any, "any");
  const accounts = await provider.send("eth_requestAccounts", []);
  const address = String(accounts?.[0] ?? "");
  const net = await provider.getNetwork();
  return { kind: "KAIA_WALLET", address, chainId: Number(net.chainId), provider };
}
