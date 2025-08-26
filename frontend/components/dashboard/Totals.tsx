"use client";
import useSWR from "swr";
import { ethers } from "ethers";
import { makeKaiaProvider, getUSDTContract, getRkUSDTContract, getVaultContract } from "@/lib/contracts";
import { Card } from "@/components/Card";
import { NumberFmt } from "@/components/Number";
import { useAppConfig } from "@/hooks/useAppConfig";
import type { AppConfig } from "@/lib/appConfig";

async function fetchTotals(cfg: AppConfig){
  const p = makeKaiaProvider(cfg);
  const usdt = getUSDTContract(cfg, p);
  const rkusdt = getRkUSDTContract(cfg, p);
  const vault = getVaultContract(cfg, p);

  const [dUSDT, dRK] = await Promise.all([
    usdt.decimals(), rkusdt.decimals()
  ]);
  
  const [vEpoch, totalStaked, rkSupply] = await Promise.all([
    vault.epochInfo().catch(()=>[0,0]),
    vault.totalStakedUSDT().catch(()=>0n),
    rkusdt.totalSupply().catch(()=>0n)
  ]);

  return {
    stakedUSDT: Number(totalStaked) / 10**Number(dUSDT),
    rkTotal: Number(rkSupply) / 10**Number(dRK),
    epoch: Number(vEpoch[0] ?? 0), 
    nextAt: Number(vEpoch[1] ?? 0) * 1000
  };
}

export function Totals(){
  const cfg = useAppConfig();
  
  const { data } = useSWR(
    cfg ? ["totals", cfg] : null, 
    cfg ? () => fetchTotals(cfg) : null, 
    { refreshInterval: 10000 }
  );
  
  if (!cfg) {
    return (
      <div className="grid md:grid-cols-2 gap-5">
        <Card title="Total Staked USDT (KAIA)">
          <div className="text-3xl font-bold animate-pulse">Loading...</div>
        </Card>
        <Card title="rkUSDT Total Supply (KAIA)">
          <div className="text-3xl font-bold animate-pulse">Loading...</div>
        </Card>
      </div>
    );
  }
  
  return (
    <div className="grid md:grid-cols-2 gap-5">
      <Card title="Total Staked USDT (KAIA)">
        <div className="text-3xl font-bold text-gradient"><NumberFmt v={data?.stakedUSDT ?? 0} /></div>
        <div className="mt-2 text-xs text-pendle-gray-500">Protocol TVL</div>
      </Card>
      <Card title="rkUSDT Total Supply (KAIA)">
        <div className="text-3xl font-bold text-gradient"><NumberFmt v={data?.rkTotal ?? 0} /></div>
        <div className="mt-2 text-xs text-pendle-gray-500">Total Minted</div>
      </Card>
    </div>
  );
}