export const CHAINS = {
  KAIA: Number(process.env.NEXT_PUBLIC_KAIA_CHAIN_ID || 1001),
  ETH: Number(process.env.NEXT_PUBLIC_ETH_CHAIN_ID || 11155111)
} as const;