"use client";
import useSWR from "swr";
import { ethers } from "ethers";
import { Card } from "./Card";
import { NumberFmt } from "./Number";
import { addr, prov, StrategyABI, VaultABI } from "@/lib/contracts";
import { TVLChart } from "./TVLChart";
import { EpochCountdown } from "./parts/EpochCountdown";

type M = { tvl: number; queued: number; epoch: number; nextAt: number; canRollover: boolean };

async function fetchOverview(): Promise<{kaia:M, eth:M}>{
  const [kaiaP, ethP] = [prov("kaia"), prov("eth")];
  const vault = new ethers.Contract(addr.vault, VaultABI, kaiaP);
  const strategy = new ethers.Contract(addr.strategy, StrategyABI, ethP);

  const [vEpoch, vCan, sEpoch, sCan, tvl, queued] = await Promise.all([
    vault.epochInfo().catch(()=>[0,0]),
    vault.canRollover().catch(()=>false),
    strategy.epochInfo(),
    strategy.canRollover(),
    strategy.totalUSDTEquivalent().catch(()=>0n),
    strategy.queuedWithdrawalUSDT().catch(()=>0n)
  ]);

  const toNum = (x:any)=> Number(x?.toString?.() ?? x);
  return {
    kaia: { tvl: 0, queued: 0, epoch: toNum(vEpoch[0]), nextAt: toNum(vEpoch[1])*1000, canRollover: Boolean(vCan) },
    eth:  { tvl: Number(tvl)/1e6, queued: Number(queued)/1e6, epoch: toNum(sEpoch[0]), nextAt: toNum(sEpoch[1])*1000, canRollover: Boolean(sCan) }
  };
}

export function Overview(){
  const { data } = useSWR("overview", fetchOverview, { refreshInterval: 10_000 });
  return (
    <div className="grid md:grid-cols-3 gap-5">
      <Card title="ETH Strategy — TVL (USDT equiv.)">
        <div className="text-3xl font-semibold"><NumberFmt v={data?.eth.tvl ?? 0} /></div>
        <div className="text-xs text-gray-400 mt-1">Queued withdrawals: <NumberFmt v={data?.eth.queued ?? 0} /></div>
      </Card>
      <Card title="ETH Strategy — Epoch">
        <div className="text-lg">Epoch #{data?.eth.epoch ?? 0}</div>
        <EpochCountdown nextAt={data?.eth.nextAt ?? 0} />
        <div className="text-xs text-gray-400 mt-2">{data?.eth.canRollover ? "Rollover due" : "Not due"}</div>
      </Card>
      <Card title="Bridge Health">
        <BridgeHealth/>
      </Card>

      <div className="md:col-span-3 card p-5">
        <div className="text-sm text-gray-400 mb-2">TVL (sampled)</div>
        <TVLChart/>
      </div>
    </div>
  );
}

function BridgeHealth(){
  const url = process.env.NEXT_PUBLIC_BRIDGE_HEALTH_URL!;
  const { data } = useSWR(url, (u)=>fetch(u).then(r=>r.json()), { refreshInterval: 5000 });
  if (!data) return <div className="text-gray-500 text-sm">Loading…</div>;
  return (
    <div className="text-sm space-y-1">
      <div>status: <span className="text-green-400">{data.status}</span></div>
      <div>KAIA block: {data.kaiaBlock}</div>
      <div>ETH block: {data.ethBlock}</div>
      <div className="text-xs text-gray-400">cursors → kaia:{data.cursors?.kaia ?? "-"} / eth:{data.cursors?.eth ?? "-"}</div>
    </div>
  );
}
