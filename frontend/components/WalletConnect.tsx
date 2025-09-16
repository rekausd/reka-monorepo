"use client";
import { useUnifiedWallet } from "@/hooks/useUnifiedWallet";
import { WalletMode } from "@/lib/wallet/unified-wallet";
import { COPY } from "@/lib/copy";

export function WalletConnect() {
  const {
    address,
    isConnected,
    isConnecting,
    isInitializing,
    error,
    connect,
    disconnect,
    walletMode,
    lineProfile,
    displayName
  } = useUnifiedWallet();

  if (isInitializing) {
    return (
      <div className="w-full">
        <div className="w-full bg-white/5 border border-white/10 rounded-xl px-4 py-2.5 text-center">
          <span className="text-xs text-gray-400">Initializing...</span>
        </div>
      </div>
    );
  }

  if (isConnected && address) {
    return (
      <div className="flex items-center gap-2 w-full">
        <div className="flex-1 bg-white/5 border border-white/10 rounded-xl px-3 py-2">
          {lineProfile && (
            <div className="flex items-center gap-2 mb-1">
              <span className="text-xs text-green-400">👤 {lineProfile.displayName}</span>
            </div>
          )}
          <div className="flex items-center gap-2">
            <span className="text-xs text-gray-400">
              {walletMode === WalletMode.MINI_DAPP ? "LINE:" : "KAIA:"}
            </span>
            <span className="text-xs font-mono">{displayName}</span>
          </div>
        </div>
        <button 
          onClick={disconnect} 
          className="px-3 py-2 rounded-xl bg-white/10 hover:bg-white/20 text-xs font-medium transition-colors"
        >
          {COPY.labels.disconnect}
        </button>
      </div>
    );
  }

  return (
    <div className="w-full">
      <button
        onClick={connect}
        disabled={isConnecting}
        className="w-full bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white text-sm font-medium rounded-xl px-4 py-2.5 transition-colors"
      >
        {isConnecting ? "Connecting..." : (walletMode === WalletMode.MINI_DAPP ? "Connect LINE Wallet" : COPY.labels.connect)}
      </button>
      {error && <div className="mt-2 text-xs text-red-400">{error}</div>}
    </div>
  );
}