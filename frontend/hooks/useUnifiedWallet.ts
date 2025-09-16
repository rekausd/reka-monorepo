"use client";
import { useState, useEffect, useCallback } from 'react';
import {
  walletService,
  initializeWallet,
  connectWallet,
  disconnectWallet,
  WalletMode,
  getLineProfile
} from '@/lib/wallet/unified-wallet';

export function useUnifiedWallet() {
  const [address, setAddress] = useState<string>('');
  const [chainId, setChainId] = useState<number>(0);
  const [isConnecting, setIsConnecting] = useState(false);
  const [isInitializing, setIsInitializing] = useState(true);
  const [error, setError] = useState<string>('');
  const [walletMode, setWalletMode] = useState<WalletMode>(WalletMode.KAIA);
  const [lineProfile, setLineProfile] = useState<any>(null);

  // Initialize wallet service on mount
  useEffect(() => {
    (async () => {
      try {
        await initializeWallet();
        const state = walletService.getState();
        setWalletMode(state.mode);
        setLineProfile(state.lineProfile);
        // Sync any pre-authorized wallet state (KAIA accounts, etc.)
        if (state.address) setAddress(state.address);
        if (state.chainId) setChainId(state.chainId);
      } catch (err) {
        console.error('Wallet initialization error:', err);
      } finally {
        setIsInitializing(false);
      }
    })();
  }, []);

  const handleConnect = useCallback(async () => {
    setIsConnecting(true);
    setError('');

    try {
      const result = await connectWallet();
      setAddress(result.address);
      setChainId(result.chainId);

      // Get LINE profile if in Mini Dapp mode
      if (walletMode === WalletMode.MINI_DAPP) {
        const profile = await getLineProfile();
        setLineProfile(profile);
      }
    } catch (err: any) {
      console.error('Connection error:', err);
      setError(err?.message || 'Failed to connect wallet');
    } finally {
      setIsConnecting(false);
    }
  }, [walletMode]);

  const handleDisconnect = useCallback(async () => {
    try {
      await disconnectWallet();
      setAddress('');
      setChainId(0);
      setLineProfile(null);
    } catch (err) {
      console.error('Disconnect error:', err);
    }
  }, []);

  // Listen for account/chain changes (KAIA mode only)
  useEffect(() => {
    if (walletMode !== WalletMode.KAIA) return;
    if (typeof window === 'undefined') return;

    const w = window as any;
    const injected = w.kaia ?? w.klaytn;
    if (!injected) return;

    const handleAccountsChanged = (accounts: string[]) => {
      if (accounts[0]) {
        setAddress(accounts[0]);
      } else {
        handleDisconnect();
      }
    };

    const handleChainChanged = (chainId: string) => {
      setChainId(parseInt(chainId, 16));
    };

    injected.on('accountsChanged', handleAccountsChanged);
    injected.on('chainChanged', handleChainChanged);

    return () => {
      injected.removeListener('accountsChanged', handleAccountsChanged);
      injected.removeListener('chainChanged', handleChainChanged);
    };
  }, [walletMode, handleDisconnect]);

  return {
    // State
    address,
    chainId,
    isConnecting,
    isInitializing,
    error,
    isConnected: !!address,
    walletMode,
    lineProfile,

    // Actions
    connect: handleConnect,
    disconnect: handleDisconnect,

    // Utilities
    isInMiniDappMode: walletMode === WalletMode.MINI_DAPP,
    displayName: lineProfile?.displayName || address?.slice(0, 6) + '...' + address?.slice(-4),
    provider: walletService.getProvider(),
    signer: walletService.getSigner()
  };
}
