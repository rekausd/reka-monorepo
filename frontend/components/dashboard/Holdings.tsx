"use client";
import useSWR from "swr";
import { ethers } from "ethers";
import { addr, ethProvider, StrategyABI } from "@/lib/contracts";
import { Card } from "@/components/Card";
import { NumberFmt } from "@/components/Number";

async function fetchHoldings(){
  const p = ethProvider();
  const s = new ethers.Contract(addr.strategy, StrategyABI, p);
  const [usdtEq, sUSDe] = await Promise.all([
    s.totalUSDTEquivalent().catch(()=>0n),
    s.totalSUSDe().catch(()=>0n)
  ]);
  return { usdtEq: Number(usdtEq)/1e6, sUSDe: Number(sUSDe)/1e18 };
}

export function Holdings(){
  const { data } = useSWR("holdings", fetchHoldings, { refreshInterval: 10000 });
  return (
    <Card title="ETH Strategy Holdings (Read-only)">
      <div className="text-sm text-gray-300">USDT Equivalent: <b><NumberFmt v={data?.usdtEq ?? 0}/></b></div>
      <div className="text-sm text-gray-300 mt-1">sUSDe: <b><NumberFmt v={data?.sUSDe ?? 0}/></b></div>
    </Card>
  );
}