import { ethers } from "ethers";
import type { AppConfig } from "@/lib/appConfig";

const IFACE = new ethers.Interface([
  "event CCIPReceived(bytes32 indexed messageId, uint64 indexed srcSelector, address indexed sink, uint256 amount, bool tokenTransfer)"
]);

export type CCIPRow = {
  tx: string;
  ts: number;
  amount: string;
  tokenTransfer: boolean;
};

export async function fetchCCIPStats(cfg: AppConfig, maxItems = 10) {
  if (!cfg.ethRpc || !cfg.sepoliaReceiver) {
    return { totalAmount: 0n, count: 0, rows: [] as CCIPRow[] };
  }

  const p = new ethers.JsonRpcProvider(cfg.ethRpc);
  const addr = cfg.sepoliaReceiver as string;

  const latest = await p.getBlockNumber();
  const from = Number.isFinite(cfg.sepoliaStartBlock || 0) ? (cfg.sepoliaStartBlock || 0) : 0;

  // Naive single-range scan (ok for testnet). For mainnet use chunking/pagination.
  const logs = await p.getLogs({
    address: addr,
    fromBlock: from,
    toBlock: latest,
    topics: [IFACE.getEvent("CCIPReceived")!.topicHash]
  });

  let total = 0n;
  const rows: CCIPRow[] = [];

  for (let i = logs.length - 1; i >= 0 && rows.length < maxItems; i--) {
    const lg = logs[i];
    const ev = IFACE.parseLog(lg);
    if (!ev) continue;

    const amount: bigint = ev.args[3] as bigint;
    total += amount;

    const blk = await p.getBlock(lg.blockNumber);
    rows.push({
      tx: lg.transactionHash,
      ts: Number(blk?.timestamp ?? 0) * 1000,
      amount: amount.toString(),
      tokenTransfer: Boolean(ev.args[4])
    });
  }

  return { totalAmount: total, count: logs.length, rows };
}