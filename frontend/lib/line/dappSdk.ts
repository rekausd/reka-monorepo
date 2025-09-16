let sdkPromise: Promise<any> | null = null;

/**
 * Initialize Mini Dapp SDK AFTER LIFF has finished init.
 * Ensure singleton: call exactly once.
 */
export async function initDappSdk() {
  if (typeof window === 'undefined') {
    throw new Error('Mini Dapp SDK can only be initialized on client side');
  }

  if (sdkPromise) return sdkPromise;
  const clientId = process.env.NEXT_PUBLIC_DAPP_CLIENT_ID!;
  if (!clientId) throw new Error('Missing NEXT_PUBLIC_DAPP_CLIENT_ID');

  const chainId = process.env.NEXT_PUBLIC_KAIA_CHAIN_ID || '1001';

  // Dynamic import to prevent SSR issues
  const DappPortalSDK = (await import('@linenext/dapp-portal-sdk')).default;
  sdkPromise = DappPortalSDK.init({ clientId, chainId });

  const sdk = await sdkPromise;

  // If unsupported environment, show built-in guide
  if (!sdk.isSupportedBrowser()) {
    await sdk.showUnsupportedBrowserGuide();
  }
  return sdk;
}

/** Get EIP-1193 provider from the SDK (used by viem/ethers). */
export async function getWalletProvider() {
  const sdk = await initDappSdk();
  return sdk.getWalletProvider(); // EIP-1193 compatible
}