// Legacy wallet.ts - now redirects to new kaia module
export { 
  connect as connectKaiaWallet,
  getProvider,
  getSigner,
  disconnect,
  getAccounts,
  getChainId
} from "./wallet/kaia";