"use client";
import { useState } from "react";
import useSWR from "swr";
import { ethers } from "ethers";
import { addr, prov, MetaSwapABI } from "@/lib/contracts";
import { NumberFmt } from "../Number";

const USDT_DEC = 6, USDE_DEC = 18;

async function fetchQuotes(usdt:number){
  const c = new ethers.Contract(addr.metaSwap, MetaSwapABI, prov("eth"));
  const usdtIn = BigInt(Math.floor(usdt * 10**USDT_DEC));
  const [outUSDe, backUSDT] = await Promise.all([
    c.quoteUSDTtoUSDe(usdtIn),
    c.quoteUSDetoUSDT(BigInt(10**USDE_DEC))
  ]);
  return { usdeOut: Number(outUSDe)/1e18, backUsdtPer1USDe: Number(backUSDT)/1e6 };
}

export function QuoteTester(){
  const [amt, setAmt] = useState(1000);
  const { data } = useSWR(["q", amt], ()=>fetchQuotes(amt), { refreshInterval: 15000 });
  return (
    <div className="grid md:grid-cols-2 gap-4">
      <div className="flex items-center gap-3">
        <label className="text-sm">USDT amount</label>
        <input type="number" className="bg-transparent border rounded px-2 py-1 w-40"
          value={amt} onChange={e=>setAmt(Number(e.target.value))}/>
      </div>
      <div className="text-sm">
        {data ? <>
          <div>USDT → USDe: <NumberFmt v={data.usdeOut}/> (for {amt} USDT)</div>
          <div>USDe → USDT (per 1 USDe): <NumberFmt v={data.backUsdtPer1USDe}/> USDT</div>
        </> : <div className="text-gray-500">Fetching quotes…</div>}
      </div>
    </div>
  );
}
