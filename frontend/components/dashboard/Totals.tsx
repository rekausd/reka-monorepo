"use client";
import { Card } from "@/components/Card";
import { NumberFmt } from "@/components/Number";
import { useKaiaTotals } from "@/hooks/useKaiaStats";

export function Totals(){
  const { totals } = useKaiaTotals();
  const deposited = totals ? Number(totals.totalDeposited)/10**(totals.decU||6) : 0;
  const rkTot     = totals ? Number(totals.rkSupply)/10**(totals.decR||6) : 0;

  return (
    <div className="grid md:grid-cols-2 gap-5">
      <Card title="Protocol USDT (Cumulative Deposited)">
        <div className="text-3xl font-semibold text-gradient"><NumberFmt v={deposited} /></div>
        <div className="mt-2 text-xs text-pendle-gray-500">Total Lifetime Deposits</div>
      </Card>
      <Card title="rkUSDT Total Supply">
        <div className="text-3xl font-semibold text-gradient"><NumberFmt v={rkTot} /></div>
        <div className="mt-2 text-xs text-pendle-gray-500">Total Minted</div>
      </Card>
    </div>
  );
}