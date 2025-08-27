import { ethers } from "ethers";
import { ERC20, VaultABI } from "@/lib/contracts";
import type { AppConfig } from "@/lib/appConfig";

const VaultIface = new ethers.Interface([
  "event Deposit(address indexed owner, uint256 amount)"
]);

export async function sumDepositsByLogs(cfg: AppConfig){
  const p = new ethers.JsonRpcProvider(cfg.kaiaRpc);
  const vault = cfg.vault;

  const fromBlock = (cfg.kaiaStartBlock && Number.isFinite(cfg.kaiaStartBlock)) ? cfg.kaiaStartBlock! : 0;
  const latest = await p.getBlockNumber();

  // chunked range (avoid provider limits)
  const step = 5_000n; // Kairos limit-friendly
  let start = BigInt(fromBlock);
  let end = BigInt(latest);
  let sum = 0n;

  const topic = VaultIface.getEvent("Deposit")!.topicHash;
  const addr = [vault];

  while (start <= end) {
    const hi = start + step;
    const to = hi < end ? hi : end;

    const logs = await p.getLogs({
      address: addr,
      topics: [topic],
      fromBlock: Number(start),
      toBlock: Number(to)
    });

    for (const lg of logs) {
      const parsed = VaultIface.parseLog(lg);
      if (!parsed) continue;
      const amount: bigint = parsed.args[1] as bigint; // amount
      sum += amount;
    }

    start = to + 1n;
  }

  return sum;
}

export async function readTotals(cfg: AppConfig){
  const p = new ethers.JsonRpcProvider(cfg.kaiaRpc);
  const usdt = new ethers.Contract(cfg.usdt, ERC20, p);
  const rk   = new ethers.Contract(cfg.rkUSDT, ERC20, p);
  const vault = new ethers.Contract(cfg.vault, VaultABI, p);

  const [dU, dR] = await Promise.all([
    usdt.decimals().catch(()=>6),
    rk.decimals().catch(()=>6),
  ]);

  // 1) Preferred: contract view
  let cumul: bigint = 0n;
  try {
    cumul = await vault.totalDepositedUSDT();
    if (cumul === 0n) throw new Error("zero, fall back");
  } catch {
    // 2) Fallback: scan Deposit events
    cumul = await sumDepositsByLogs(cfg).catch(()=>0n);
  }

  // rk supply for display (unchanged)
  const rkSupply = await (rk.totalSupply?.() ?? 0n).catch(()=>0n);

  // epoch info (if exposed)
  const [e0, eDur] = await Promise.all([
    vault.epoch0Start().catch(()=>0),
    vault.epochDuration().catch(()=>0),
  ]);

  return {
    decU: Number(dU), decR: Number(dR),
    totalDeposited: cumul,
    rkSupply,
    epoch0: Number(e0), epochDur: Number(eDur)
  };
}