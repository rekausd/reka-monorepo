"use client";
import { useAppConfig } from "@/hooks/useAppConfig";
import { useKaiaTotals } from "@/hooks/useKaiaStats";
import { useState } from "react";

export function EarningsEstimator({ address }:{ address?: string }){
  const cfg = useAppConfig();
  const { totals } = useKaiaTotals();
  const [inputBalance, setInputBalance] = useState("1000");
  
  const apy = (cfg?.strategyApyBps ?? 1100)/10000; // 0.11
  const bal = Number(inputBalance) || 0;
  const yearly = bal * apy;
  const daily = yearly/365;
  
  return (
    <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
      <div className="text-sm font-medium">Earnings Calculator</div>
      <div className="text-xs text-gray-400 mt-1">Based on APY from config; for demo only.</div>
      
      <div className="mt-3">
        <input
          type="number"
          value={inputBalance}
          onChange={(e) => setInputBalance(e.target.value)}
          placeholder="Enter amount"
          className="w-full bg-transparent border border-white/15 rounded-xl px-3 py-2 text-sm focus:outline-none focus:border-white/40 transition-colors"
        />
      </div>
      
      <div className="mt-3 space-y-1">
        <div className="text-sm">Balance: <b>{bal.toLocaleString(undefined,{maximumFractionDigits:2})}</b> rkUSDT</div>
        <div className="text-sm">Est. daily: <b>{daily.toLocaleString(undefined,{maximumFractionDigits:2})}</b> USDT</div>
        <div className="text-sm">Est. yearly: <b>{yearly.toLocaleString(undefined,{maximumFractionDigits:2})}</b> USDT</div>
        <div className="text-xs text-gray-500 mt-2">APY: {(apy*100).toFixed(2)}%</div>
      </div>
    </div>
  );
}