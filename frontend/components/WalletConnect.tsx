"use client";
import { useKaiaWallet } from "@/lib/wallet/kaia";
import { COPY } from "@/lib/copy";

export function WalletConnect(){
  const { address, isConnected, isConnecting, error, connect, disconnect } = useKaiaWallet();

  if (isConnected && address) {
    return (
      <div className="flex items-center gap-2 w-full">
        <div className="flex-1 bg-white/5 border border-white/10 rounded-xl px-3 py-2 flex items-center gap-2">
          <span className="text-xs text-gray-400">KAIA:</span>
          <span className="text-xs font-mono">{address.slice(0,6)}...{address.slice(-4)}</span>
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
        {isConnecting ? "Connecting..." : COPY.labels.connect}
      </button>
      {error && <div className="mt-2 text-xs text-red-400">{error}</div>}
    </div>
  );
}