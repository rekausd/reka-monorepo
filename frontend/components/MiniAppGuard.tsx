"use client";
import { walletService } from "@/lib/wallet/unified-wallet";
import { useEffect, useState } from "react";

export function MiniAppGuard({ children }: { children: React.ReactNode }) {
  const [isInitialized, setIsInitialized] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        console.log('Initializing wallet service...');
        await walletService.initialize();
        console.log('Wallet service initialized successfully');
        setIsInitialized(true);
      } catch (err) {
        console.error('Failed to initialize:', err);
        setError(err instanceof Error ? err.message : String(err));
        // Still allow app to load even if initialization fails
        setIsInitialized(true);
      }
    })();
  }, []);

  if (!isInitialized) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[#0B0C10]">
        <div className="text-center">
          <div className="w-12 h-12 border-2 border-indigo-600 border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
          <p className="text-gray-400 text-sm">Initializing Mini App...</p>
          {error && (
            <p className="text-red-400 text-xs mt-2">Error: {error}</p>
          )}
        </div>
      </div>
    );
  }

  return <>{children}</>;
}