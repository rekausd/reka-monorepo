"use client";
import useSWR from "swr";
import { ethers } from "ethers";
import { addr, prov, StrategyABI, MetaSwapABI } from "@/lib/contracts";
import { Card } from "./Card";
import { NumberFmt } from "./Number";
import { EpochCountdown } from "./parts/EpochCountdown";
import { QuoteTester } from "./parts/QuoteTester";

async function fetchEth(){
  const s = new ethers.Contract(addr.strategy, StrategyABI, prov("eth"));
  const [ep, due, tvl, q, slip, recip] = await Promise.all([
    s.epochInfo(), s.canRollover(), s.totalUSDTEquivalent(), s.queuedWithdrawalUSDT(), s.slippageBps(), s.kaiaRecipient()
  ]);
  return {
    epoch: Number(ep[0]), nextAt: Number(ep[1])*1000, due: Boolean(due),
    tvl: Number(tvl)/1e6, queued: Number(q)/1e6, slippage: Number(slip), recipient: recip
  };
}

export function EthPanel(){
  const { data } = useSWR("eth", fetchEth, { refreshInterval: 10_000 });
  return (
    <div className="grid md:grid-cols-3 gap-5">
      <Card title="ETH Strategy — TVL">
        <div className="text-3xl"><NumberFmt v={data?.tvl ?? 0} /></div>
        <div className="text-xs text-gray-400 mt-1">Queued: <NumberFmt v={data?.queued ?? 0} /></div>
      </Card>
      <Card title="ETH Strategy — Epoch">
        <div>Epoch #{data?.epoch ?? 0}</div>
        <EpochCountdown nextAt={data?.nextAt ?? 0}/>
        <div className="text-xs text-gray-400 mt-2">{data?.due ? "Rollover due" : "Not due"}</div>
      </Card>
      <Card title="Params">
        <div className="text-sm text-gray-300">Slippage bps: {data?.slippage ?? "-"}</div>
        <div className="text-sm text-gray-300">KAIA recipient: <span className="font-mono">{data?.recipient}</span></div>
      </Card>

      <div className="md:col-span-3 card p-5">
        <div className="mb-3 text-sm text-gray-400">MetaSwapAdapter — Live Quote</div>
        <QuoteTester />
      </div>
    </div>
  );
}
