export interface BridgeEventParsed {
  chainId: number;
  txHash: string;
  logIndex: number;
  from: string;
  to: string;
  amount: bigint;
  srcChainId: bigint;
  dstChainId: bigint;
  nonce: bigint;
}
