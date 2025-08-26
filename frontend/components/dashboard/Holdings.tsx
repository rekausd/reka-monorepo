"use client";
import useSWR from "swr";
import { ethers } from "ethers";
import { makeEthProvider, getStrategyContract } from "@/lib/contracts";
import { Card } from "@/components/Card";
import { NumberFmt } from "@/components/Number";
import { useAppConfig } from "@/hooks/useAppConfig";
import type { AppConfig } from "@/lib/appConfig";

async function fetchHoldings(cfg: AppConfig){
  const p = makeEthProvider(cfg);
  if (!p || !cfg.ethStrategy) {
    return { usdtEq: 0, sUSDe: 0 };
  }
  
  const s = getStrategyContract(cfg, p);
  if (!s) {
    return { usdtEq: 0, sUSDe: 0 };
  }
  
  const [usdtEq, sUSDe] = await Promise.all([
    s.totalUSDTEquivalent().catch(()=>0n),
    s.totalSUSDe().catch(()=>0n)
  ]);
  return { usdtEq: Number(usdtEq)/1e6, sUSDe: Number(sUSDe)/1e18 };
}

export function Holdings(){
  const cfg = useAppConfig();
  
  const { data } = useSWR(
    cfg ? ["holdings", cfg] : null,
    cfg ? () => fetchHoldings(cfg) : null,
    { refreshInterval: 10000 }
  );
  
  if (!cfg) {
    return (
      <Card title="ETH Strategy Holdings">
        <div className="space-y-3">
          <div className="text-xl font-bold animate-pulse">Loading...</div>
        </div>
      </Card>
    );
  }
  
  return (
    <Card title="ETH Strategy Holdings">
      <div className="space-y-3">
        <div className="glass-panel p-3 rounded-lg">
          <div className="text-xs text-pendle-gray-400 mb-1">USDT Equivalent</div>
          <div className="text-xl font-bold text-gradient"><NumberFmt v={data?.usdtEq ?? 0}/></div>
        </div>
        <div className="glass-panel p-3 rounded-lg">
          <div className="text-xs text-pendle-gray-400 mb-1">sUSDe Holdings</div>
          <div className="text-xl font-bold text-gradient"><NumberFmt v={data?.sUSDe ?? 0}/></div>
        </div>
        <div className="text-xs text-pendle-gray-500 mt-2">Read-only Ethereum data</div>
      </div>
    </Card>
  );
}