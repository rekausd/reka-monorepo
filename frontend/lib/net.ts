export function kaiaNetworkTag(chainId?: number): string {
  if (!chainId) return "";
  if (chainId === 8217) return "Kaia Mainnet";
  if (chainId === 1001) return "Kairos Testnet";
  return `Chain ${chainId}`;
}

