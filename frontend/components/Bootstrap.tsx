"use client";

import { useEffect, useState } from 'react';
import { initLiff } from '@/lib/line/liffClient';
import { initDappSdk } from '@/lib/line/dappSdk';

/**
 * Bootstrap component - initializes LIFF and Mini Dapp SDK
 * Following KiloLend pattern: LIFF first, then SDK
 */
export function Bootstrap({ children }: { children: React.ReactNode }) {
  const [isInitialized, setIsInitialized] = useState(false);
  const [error, setError] = useState<string>('');

  useEffect(() => {
    let mounted = true;

    const initialize = async () => {
      try {
        console.log('[Bootstrap] Starting initialization sequence...');

        // Step 1: Initialize LIFF (must be first)
        console.log('[Bootstrap] Step 1: Initializing LIFF...');
        await initLiff();

        // Step 2: Initialize Mini Dapp SDK (must be after LIFF)
        console.log('[Bootstrap] Step 2: Initializing Mini Dapp SDK...');
        await initDappSdk();

        console.log('[Bootstrap] Initialization complete');

        if (mounted) {
          setIsInitialized(true);
        }
      } catch (err) {
        console.error('[Bootstrap] Initialization error:', err);
        if (mounted) {
          setError(err instanceof Error ? err.message : 'Initialization failed');
          // Still mark as initialized to show the app
          setIsInitialized(true);
        }
      }
    };

    // Start initialization
    initialize();

    // Cleanup
    return () => {
      mounted = false;
    };
  }, []);

  // Show loading screen while initializing
  if (!isInitialized) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[#0B0C10]">
        <div className="text-center">
          <div className="w-12 h-12 border-2 border-green-600 border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
          <p className="text-gray-400 text-sm">Initializing LINE Mini Dapp...</p>
        </div>
      </div>
    );
  }

  // Show error if initialization failed (but still render the app)
  if (error) {
    console.warn('[Bootstrap] Initialization had errors but continuing:', error);
  }

  return <>{children}</>;
}