import { ethers } from 'ethers';

interface MiniDappWalletResult {
  address: string;
  provider: any;
}

class MiniDappService {
  private static instance: MiniDappService;
  private sdkInstance: any = null;
  private walletProvider: any = null;
  private initialized = false;

  private constructor() {}

  static getInstance(): MiniDappService {
    if (!MiniDappService.instance) {
      MiniDappService.instance = new MiniDappService();
    }
    return MiniDappService.instance;
  }

  async initialize(): Promise<boolean> {
    if (typeof window === 'undefined') return false;
    if (this.initialized) return true;

    const clientId = process.env.NEXT_PUBLIC_DAPP_CLIENT_ID;
    if (!clientId) {
      console.warn('Mini Dapp Client ID not configured');
      return false;
    }

    try {
      // Dynamic import to avoid SSR issues
      const { default: DappPortalSDK } = await import('@linenext/dapp-portal-sdk');

      const config = {
        clientId,
        chainId: process.env.NEXT_PUBLIC_KAIA_CHAIN_ID || '1001',
      };

      this.sdkInstance = await DappPortalSDK.init(config);
      this.initialized = true;

      // Check browser support
      if (!this.sdkInstance.isSupportedBrowser()) {
        console.warn('Browser not supported for Mini Dapp SDK');
        await this.sdkInstance.showUnsupportedBrowserGuide();
        return false;
      }

      console.log('Mini Dapp SDK initialized successfully');
      return true;
    } catch (error) {
      console.error('Failed to initialize Mini Dapp SDK:', error);
      return false;
    }
  }

  async getWalletProvider(): Promise<any> {
    if (!this.initialized) {
      throw new Error('Mini Dapp SDK not initialized');
    }

    if (!this.walletProvider) {
      this.walletProvider = await this.sdkInstance.getWalletProvider();
    }

    return this.walletProvider;
  }

  async connectWallet(): Promise<MiniDappWalletResult> {
    try {
      const provider = await this.getWalletProvider();

      // Request account access
      const accounts = await provider.request({
        method: 'kaia_requestAccounts'
      }) as string[];

      if (!accounts || accounts.length === 0) {
        throw new Error('No accounts returned from wallet');
      }

      console.log('Wallet connected:', accounts[0]);

      return {
        address: accounts[0],
        provider
      };
    } catch (error) {
      console.error('Failed to connect Mini Dapp wallet:', error);

      // Handle specific error codes
      if ((error as any).code === -32001) {
        throw new Error('User rejected the connection request');
      } else if ((error as any).code === -32004) {
        throw new Error('Invalid account address');
      } else if ((error as any).code === -32005) {
        throw new Error('Authentication failed - please try again');
      } else if ((error as any).code === -32006) {
        throw new Error('Wallet not connected');
      }

      throw error;
    }
  }

  async disconnectWallet(): Promise<void> {
    if (this.walletProvider && this.walletProvider.disconnectWallet) {
      await this.walletProvider.disconnectWallet();
    }
    this.walletProvider = null;
  }

  async signMessage(message: string, address: string): Promise<string> {
    const provider = await this.getWalletProvider();

    try {
      const signature = await provider.request({
        method: 'personal_sign',
        params: [message, address]
      });

      return signature;
    } catch (error) {
      console.error('Failed to sign message:', error);
      throw error;
    }
  }

  async sendTransaction(transaction: any): Promise<string> {
    const provider = await this.getWalletProvider();

    try {
      const txHash = await provider.request({
        method: 'kaia_sendTransaction',
        params: [transaction]
      });

      return txHash;
    } catch (error) {
      console.error('Failed to send transaction:', error);
      throw error;
    }
  }

  async getEthersProvider(): Promise<ethers.BrowserProvider> {
    const walletProvider = await this.getWalletProvider();
    return new ethers.BrowserProvider(walletProvider, 'any');
  }

  isInitialized(): boolean {
    return this.initialized;
  }

  isInMiniDappEnvironment(): boolean {
    // Check if we're in a LINE Mini Dapp environment
    if (typeof window === 'undefined') return false;

    const userAgent = window.navigator.userAgent.toLowerCase();
    return userAgent.includes('line') || !!(window as any).liff;
  }
}

// Export singleton instance
export const miniDappService = MiniDappService.getInstance();

// Export convenience functions
export const initializeMiniDapp = () => miniDappService.initialize();
export const connectMiniDappWallet = () => miniDappService.connectWallet();
export const disconnectMiniDappWallet = () => miniDappService.disconnectWallet();
export const getMiniDappEthersProvider = () => miniDappService.getEthersProvider();
export const isInMiniDappEnvironment = () => miniDappService.isInMiniDappEnvironment();