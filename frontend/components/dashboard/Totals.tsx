"use client";
import { Card } from "@/components/Card";
import { NumberFmt } from "@/components/Number";
import { useKaiaTotals } from "@/hooks/useKaiaStats";

export function Totals(){
  const { totals } = useKaiaTotals();
  const val = totals ? Number(totals.rkSupply)/10**(totals.decR||6) : 0;

  return (
    <div className="grid md:grid-cols-2 gap-5">
      <Card title="USDT Staked (proxy)">
        <div className="text-3xl font-semibold text-gradient"><NumberFmt v={val} /></div>
        <div className="mt-2 text-xs text-pendle-gray-500">Protocol TVL</div>
      </Card>
      <Card title="rkUSDT Total Supply">
        <div className="text-3xl font-semibold text-gradient"><NumberFmt v={val} /></div>
        <div className="mt-2 text-xs text-pendle-gray-500">Total Minted</div>
      </Card>
    </div>
  );
}