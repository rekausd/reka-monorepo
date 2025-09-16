import liff from '@line/liff';

export interface LiffProfile {
  userId: string;
  displayName: string;
  pictureUrl?: string;
  statusMessage?: string;
}

export interface LiffContext {
  type?: string;
  userId?: string;
  roomId?: string;
  groupId?: string;
}

class LiffService {
  private static instance: LiffService;
  private initialized = false;
  private profile: LiffProfile | null = null;

  private constructor() {}

  static getInstance(): LiffService {
    if (!LiffService.instance) {
      LiffService.instance = new LiffService();
    }
    return LiffService.instance;
  }

  async initialize(liffId?: string): Promise<boolean> {
    if (typeof window === 'undefined') return false;
    if (this.initialized) return true;

    const id = liffId || process.env.NEXT_PUBLIC_LIFF_ID;
    if (!id) {
      console.warn('LIFF ID not provided');
      return false;
    }

    try {
      await liff.init({ liffId: id });
      await liff.ready;
      this.initialized = true;
      console.log('LIFF initialized successfully');
      return true;
    } catch (error) {
      console.error('LIFF initialization failed:', error);
      return false;
    }
  }

  isInLiff(): boolean {
    if (typeof window === 'undefined') return false;
    return liff.isInClient();
  }

  isLoggedIn(): boolean {
    return this.initialized && liff.isLoggedIn();
  }

  async login(): Promise<void> {
    if (!this.initialized) {
      throw new Error('LIFF not initialized');
    }
    if (!this.isLoggedIn()) {
      await liff.login();
    }
  }

  logout(): void {
    if (this.initialized && this.isLoggedIn()) {
      liff.logout();
      this.profile = null;
    }
  }

  async getProfile(): Promise<LiffProfile | null> {
    if (!this.initialized || !this.isLoggedIn()) {
      return null;
    }

    if (this.profile) {
      return this.profile;
    }

    try {
      const profile = await liff.getProfile();
      this.profile = {
        userId: profile.userId,
        displayName: profile.displayName,
        pictureUrl: profile.pictureUrl,
        statusMessage: profile.statusMessage,
      };
      return this.profile;
    } catch (error) {
      console.error('Failed to get LIFF profile:', error);
      return null;
    }
  }

  getContext(): LiffContext | null {
    if (!this.initialized) return null;
    return liff.getContext();
  }

  async shareMessage(messages: any[]): Promise<void> {
    if (!this.initialized) {
      throw new Error('LIFF not initialized');
    }

    if (!liff.isApiAvailable('shareTargetPicker')) {
      throw new Error('Share target picker is not available');
    }

    await liff.shareTargetPicker(messages);
  }

  minimizeWindow(): void {
    if (this.initialized && (liff as any).liffWindow?.minimize) {
      (liff as any).liffWindow.minimize();
    }
  }

  closeWindow(): void {
    if (this.initialized) {
      liff.closeWindow();
    }
  }

  getLanguage(): string {
    if (!this.initialized) return 'en';
    return liff.getLanguage();
  }

  isApiAvailable(api: string): boolean {
    return this.initialized && liff.isApiAvailable(api);
  }
}

// Export singleton instance
export const liffService = LiffService.getInstance();

// Export convenience functions
export const initializeLiff = (liffId?: string) => liffService.initialize(liffId);
export const getLiffProfile = () => liffService.getProfile();
export const isInLiffEnvironment = () => liffService.isInLiff();
export const loginToLiff = () => liffService.login();
export const logoutFromLiff = () => liffService.logout();