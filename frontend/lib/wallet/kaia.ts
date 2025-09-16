"use client";
import "@kaiachain/ethers-ext";
import { ethers } from "ethers";
import { useState, useEffect, useCallback } from "react";
import { getWalletProvider } from "@/lib/line/dappSdk";

let currentProvider: ethers.BrowserProvider | null = null;
let currentSigner: ethers.Signer | null = null;
let currentAccount: string | null = null;
let miniDappProvider: any | null = null;

// Check Mini Dapp mode at module level
export const isMiniDappMode = !!(process.env.NEXT_PUBLIC_LIFF_ID && process.env.NEXT_PUBLIC_DAPP_CLIENT_ID);

function detectKaiaProvider(): any | null {
  if (typeof window === "undefined") return null;

  // If in Mini Dapp mode, don't look for KAIA wallet
  if (isMiniDappMode) {
    return null; // Will use Mini Dapp SDK provider
  }

  const w = window as any;
  return w.kaia ?? w.klaytn ?? null;
}

export async function getProvider(): Promise<ethers.BrowserProvider> {
  if (currentProvider) return currentProvider;

  if (isMiniDappMode) {
    // Use Mini Dapp SDK provider
    if (!miniDappProvider) {
      miniDappProvider = await getWalletProvider();
    }
    currentProvider = new ethers.BrowserProvider(miniDappProvider, "any");
    return currentProvider;
  }

  const injected = detectKaiaProvider();
  if (!injected) {
    throw new Error("Kaia Wallet not found. Please install Kaia Wallet.");
  }

  currentProvider = new ethers.BrowserProvider(injected, "any");
  return currentProvider;
}

export async function getSigner(): Promise<ethers.Signer> {
  if (currentSigner) return currentSigner;
  
  const provider = await getProvider();
  const accounts = await provider.send("eth_requestAccounts", []);
  if (!accounts?.[0]) throw new Error("No accounts found");
  
  currentAccount = accounts[0];
  currentSigner = await provider.getSigner();
  return currentSigner;
}

export async function connect(): Promise<{ address: string; chainId: number }> {
  if (isMiniDappMode) {
    // Use Mini Dapp SDK provider
    if (!miniDappProvider) {
      miniDappProvider = await getWalletProvider();
    }

    // Request accounts through Mini Dapp SDK (using kaia_requestAccounts)
    const accounts = await miniDappProvider.request({ method: 'kaia_requestAccounts' });
    const address = accounts?.[0];

    if (!address) throw new Error("No accounts found");

    currentAccount = address;
    const provider = new ethers.BrowserProvider(miniDappProvider, "any");
    currentProvider = provider;
    currentSigner = await provider.getSigner();

    const network = await provider.getNetwork();
    const chainId = Number(network.chainId);

    return { address, chainId };
  }

  // Fallback to regular Kaia wallet flow
  const provider = await getProvider();
  const accounts = await provider.send("eth_requestAccounts", []);
  const address = accounts?.[0];

  if (!address) throw new Error("No accounts found");

  currentAccount = address;
  currentSigner = await provider.getSigner();

  const network = await provider.getNetwork();
  const chainId = Number(network.chainId);

  // Check chain ID
  const expectedChainId = Number(process.env.NEXT_PUBLIC_KAIA_CHAIN_ID || 8217);
  if (chainId !== expectedChainId) {
    try {
      await provider.send("wallet_switchEthereumChain", [
        { chainId: `0x${expectedChainId.toString(16)}` }
      ]);
      const newNetwork = await provider.getNetwork();
      return { address, chainId: Number(newNetwork.chainId) };
    } catch (switchError: any) {
      if (switchError.code === 4902) {
        throw new Error(`Please add Kaia chain (${expectedChainId}) to your wallet`);
      }
      throw new Error(`Please switch to Kaia chain (${expectedChainId})`);
    }
  }

  return { address, chainId };
}

export function disconnect() {
  currentProvider = null;
  currentSigner = null;
  currentAccount = null;
  miniDappProvider = null;
}

export async function getAccounts(): Promise<string[]> {
  if (isMiniDappMode) {
    // Mini Dapp SDK doesn't auto-connect, return empty
    return currentAccount ? [currentAccount] : [];
  }

  const provider = await getProvider();
  const accounts = await provider.send("eth_accounts", []);
  return accounts || [];
}

export async function getChainId(): Promise<number> {
  const provider = await getProvider();
  const network = await provider.getNetwork();
  return Number(network.chainId);
}

export function useKaiaWallet() {
  const [address, setAddress] = useState<string>("");
  const [chainId, setChainId] = useState<number>(0);
  const [isConnecting, setIsConnecting] = useState(false);
  const [error, setError] = useState<string>("");
  
  const handleConnect = useCallback(async () => {
    setIsConnecting(true);
    setError("");
    try {
      const result = await connect();
      setAddress(result.address);
      setChainId(result.chainId);
    } catch (err: any) {
      setError(err?.message || String(err));
    } finally {
      setIsConnecting(false);
    }
  }, []);
  
  const handleDisconnect = useCallback(() => {
    disconnect();
    setAddress("");
    setChainId(0);
  }, []);
  
  useEffect(() => {
    // Don't auto-check connection for Mini Dapp mode
    if (isMiniDappMode) return;

    // Auto-check connection on mount (for regular wallet mode)
    getAccounts().then(accounts => {
      if (accounts[0]) {
        setAddress(accounts[0]);
        getChainId().then(setChainId);
      }
    }).catch(() => {});
    
    // Listen for account changes (skip for Mini Dapp mode)
    if (isMiniDappMode) return;

    const injected = detectKaiaProvider();
    if (injected) {
      const handleAccountsChanged = (accounts: string[]) => {
        if (accounts[0]) {
          setAddress(accounts[0]);
          currentAccount = accounts[0];
        } else {
          handleDisconnect();
        }
      };
      
      const handleChainChanged = (chainId: string) => {
        setChainId(parseInt(chainId, 16));
      };
      
      injected.on("accountsChanged", handleAccountsChanged);
      injected.on("chainChanged", handleChainChanged);
      
      return () => {
        injected.removeListener("accountsChanged", handleAccountsChanged);
        injected.removeListener("chainChanged", handleChainChanged);
      };
    }
  }, [handleDisconnect]);
  
  return {
    address,
    chainId,
    isConnecting,
    error,
    isConnected: !!address,
    connect: handleConnect,
    disconnect: handleDisconnect,
    isInMiniApp: isMiniDappMode
  };
}