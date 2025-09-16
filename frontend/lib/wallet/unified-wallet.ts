"use client";
import { ethers } from 'ethers';
import { liffService, getLiffProfile } from '@/lib/line/liff-service';
import { miniDappService, connectMiniDappWallet, disconnectMiniDappWallet } from '@/lib/line/mini-dapp-service';

export enum WalletMode {
  KAIA = 'KAIA',
  MINI_DAPP = 'MINI_DAPP'
}

interface WalletState {
  mode: WalletMode;
  address: string | null;
  chainId: number;
  provider: ethers.BrowserProvider | null;
  signer: ethers.Signer | null;
  lineProfile: any | null;
}

class UnifiedWalletService {
  private static instance: UnifiedWalletService;
  private state: WalletState = {
    mode: WalletMode.KAIA,
    address: null,
    chainId: 0,
    provider: null,
    signer: null,
    lineProfile: null
  };

  private constructor() {
    this.detectMode();
  }

  static getInstance(): UnifiedWalletService {
    if (!UnifiedWalletService.instance) {
      UnifiedWalletService.instance = new UnifiedWalletService();
    }
    return UnifiedWalletService.instance;
  }

  private detectMode(): void {
    // Check if Mini Dapp environment variables are set
    if (process.env.NEXT_PUBLIC_LIFF_ID && process.env.NEXT_PUBLIC_DAPP_CLIENT_ID) {
      this.state.mode = WalletMode.MINI_DAPP;
    } else {
      this.state.mode = WalletMode.KAIA;
    }
  }

  async initialize(): Promise<void> {
    if (this.state.mode === WalletMode.MINI_DAPP) {
      // Initialize LIFF first
      const liffInitialized = await liffService.initialize();
      if (liffInitialized) {
        console.log('LIFF initialized');

        // Get LINE profile if logged in
        if (liffService.isLoggedIn()) {
          this.state.lineProfile = await getLiffProfile();
        }
      }

      // Then initialize Mini Dapp SDK
      const sdkInitialized = await miniDappService.initialize();
      if (!sdkInitialized) {
        console.warn('Mini Dapp SDK initialization failed, falling back to KAIA mode');
        this.state.mode = WalletMode.KAIA;
      }
    } else {
      // KAIA mode: detect existing authorized account without prompting
      if (typeof window !== 'undefined') {
        const w = window as any;
        const injected = w.kaia ?? w.klaytn;
        if (injected?.request) {
          try {
            const accounts: string[] = await injected.request({ method: 'eth_accounts' });
            if (accounts && accounts.length > 0) {
              const provider = new ethers.BrowserProvider(injected, 'any');
              this.state.provider = provider;
              // getSigner should resolve without a prompt if already authorized
              this.state.signer = await provider.getSigner();
              this.state.address = accounts[0];
              const network = await provider.getNetwork();
              this.state.chainId = Number(network.chainId);
            }
          } catch (e) {
            // Non-fatal: simply means no prior authorization
          }
        }
      }
    }
  }

  async connect(): Promise<{ address: string; chainId: number }> {
    if (this.state.mode === WalletMode.MINI_DAPP) {
      return this.connectMiniDapp();
    } else {
      return this.connectKaia();
    }
  }

  private async connectMiniDapp(): Promise<{ address: string; chainId: number }> {
    try {
      const { address, provider } = await connectMiniDappWallet();

      // Create ethers provider
      const ethersProvider = new ethers.BrowserProvider(provider, 'any');
      this.state.provider = ethersProvider;
      this.state.signer = await ethersProvider.getSigner();
      this.state.address = address;

      // Get chain ID
      const network = await ethersProvider.getNetwork();
      this.state.chainId = Number(network.chainId);

      return { address, chainId: this.state.chainId };
    } catch (error: any) {
      console.error('Mini Dapp connection failed:', error);
      throw new Error(error.message || 'Failed to connect wallet');
    }
  }

  private async connectKaia(): Promise<{ address: string; chainId: number }> {
    if (typeof window === 'undefined') {
      throw new Error('Window object not available');
    }

    const w = window as any;
    const injected = w.kaia ?? w.klaytn;

    if (!injected) {
      throw new Error('KAIA wallet not found. Please install KAIA wallet.');
    }

    try {
      const provider = new ethers.BrowserProvider(injected, 'any');
      const accounts = await provider.send('eth_requestAccounts', []);

      if (!accounts || accounts.length === 0) {
        throw new Error('No accounts found');
      }

      this.state.provider = provider;
      this.state.signer = await provider.getSigner();
      this.state.address = accounts[0];

      const network = await provider.getNetwork();
      this.state.chainId = Number(network.chainId);

      // Check and switch chain if needed
      const expectedChainId = Number(process.env.NEXT_PUBLIC_KAIA_CHAIN_ID || 1001);
      if (this.state.chainId !== expectedChainId) {
        await this.switchChain(expectedChainId);
      }

      return { address: this.state.address!, chainId: this.state.chainId };
    } catch (error: any) {
      console.error('KAIA connection failed:', error);
      throw new Error(error.message || 'Failed to connect KAIA wallet');
    }
  }

  async disconnect(): Promise<void> {
    if (this.state.mode === WalletMode.MINI_DAPP) {
      await disconnectMiniDappWallet();
    }

    this.state.address = null;
    this.state.provider = null;
    this.state.signer = null;
    this.state.chainId = 0;
    this.state.lineProfile = null;
  }

  private async switchChain(chainId: number): Promise<void> {
    if (!this.state.provider) return;

    try {
      await this.state.provider.send('wallet_switchEthereumChain', [
        { chainId: `0x${chainId.toString(16)}` }
      ]);
      const network = await this.state.provider.getNetwork();
      this.state.chainId = Number(network.chainId);
    } catch (error: any) {
      if (error.code === 4902) {
        throw new Error(`Please add chain ${chainId} to your wallet`);
      }
      throw new Error(`Please switch to chain ${chainId}`);
    }
  }

  getState(): WalletState {
    return { ...this.state };
  }

  isConnected(): boolean {
    return !!this.state.address;
  }

  getMode(): WalletMode {
    return this.state.mode;
  }

  getProvider(): ethers.BrowserProvider | null {
    return this.state.provider;
  }

  getSigner(): ethers.Signer | null {
    return this.state.signer;
  }

  getAddress(): string | null {
    return this.state.address;
  }

  getLineProfile(): any | null {
    return this.state.lineProfile;
  }
}

// Export singleton instance
export const walletService = UnifiedWalletService.getInstance();

// Export convenience functions
export const initializeWallet = () => walletService.initialize();
export const connectWallet = () => walletService.connect();
export const disconnectWallet = () => walletService.disconnect();
export const isWalletConnected = () => walletService.isConnected();
export const getWalletMode = () => walletService.getMode();
export const getWalletAddress = () => walletService.getAddress();
export const getLineProfile = () => walletService.getLineProfile();
