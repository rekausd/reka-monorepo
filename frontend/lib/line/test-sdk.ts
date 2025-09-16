"use client";

// Simple test file to verify SDK initialization
export async function testSDKInit() {
  console.log('=== Testing Mini Dapp SDK Initialization ===');

  const clientId = process.env.NEXT_PUBLIC_DAPP_CLIENT_ID;
  const chainId = process.env.NEXT_PUBLIC_KAIA_CHAIN_ID || '1001';

  console.log('Environment check:');
  console.log('- Client ID:', clientId);
  console.log('- Chain ID:', chainId);

  if (!clientId) {
    console.error('❌ Client ID is missing!');
    return null;
  }

  try {
    console.log('Attempting to import SDK...');
    const DappPortalSDK = (await import('@linenext/dapp-portal-sdk')).default;
    console.log('✅ SDK module imported successfully');
    console.log('SDK object:', DappPortalSDK);
    console.log('Available methods:', Object.keys(DappPortalSDK));

    console.log('Attempting to initialize SDK...');
    const sdkInstance = await DappPortalSDK.init({
      clientId: clientId,
      chainId: chainId,
    });

    console.log('✅ SDK initialized successfully!');
    console.log('SDK instance:', sdkInstance);
    console.log('Instance methods:', Object.keys(sdkInstance));

    // Test getting wallet provider
    try {
      const provider = await sdkInstance.getWalletProvider();
      console.log('✅ Wallet provider obtained:', provider);
    } catch (err) {
      console.warn('⚠️ Could not get wallet provider (expected if not connected):', err);
    }

    return sdkInstance;
  } catch (error: any) {
    console.error('❌ SDK initialization failed!');
    console.error('Error:', error);
    console.error('Error type:', error?.constructor?.name);
    console.error('Error message:', error?.message);
    console.error('Error stack:', error?.stack);
    return null;
  }
}

// Auto-run test on import in development
if (typeof window !== 'undefined' && process.env.NODE_ENV === 'development') {
  window.addEventListener('load', () => {
    console.log('Page loaded, running SDK test in 2 seconds...');
    setTimeout(() => {
      testSDKInit();
    }, 2000);
  });
}