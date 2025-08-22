export const makeEventId = (chainId: number, txHash: string, logIndex: number) =>
  `${chainId}:${txHash}:${logIndex}`;
