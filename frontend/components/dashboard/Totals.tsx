"use client";
import useSWR from "swr";
import { ethers } from "ethers";
import { addr, kaiaProvider } from "@/lib/contracts";
import { Card } from "@/components/Card";
import { NumberFmt } from "@/components/Number";
import { ERC20, VaultABI } from "@/lib/contracts";

async function fetchTotals(){
  const p = kaiaProvider();
  const usdt = new ethers.Contract(addr.kaiaUSDT, ERC20, p);
  const rkusdt = new ethers.Contract(addr.rkUSDT, ERC20, p);
  const vault = new ethers.Contract(addr.vault, VaultABI, p);

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
  const { data } = useSWR("totals", fetchTotals, { refreshInterval: 10000 });
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