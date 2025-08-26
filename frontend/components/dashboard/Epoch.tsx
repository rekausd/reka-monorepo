"use client";
import React from "react";
import useSWR from "swr";
import { ethers } from "ethers";
import { addr, kaiaProvider, VaultABI } from "@/lib/contracts";
import { Card } from "@/components/Card";

function Countdown({ nextAt }:{ nextAt:number }){
  const [n, setN] = React.useState(Math.max(0, nextAt - Date.now()));
  React.useEffect(()=>{ 
    const id = setInterval(()=>setN(Math.max(0, nextAt - Date.now())), 1000); 
    return ()=>clearInterval(id); 
  }, [nextAt]);
  const s = Math.floor(n/1000), d=Math.floor(s/86400), h=Math.floor((s%86400)/3600), m=Math.floor((s%3600)/60), sc=s%60;
  return (
    <div className="flex gap-2 mt-2">
      <span className="glass-panel px-3 py-1 rounded-lg text-sm font-medium">{d}d</span>
      <span className="glass-panel px-3 py-1 rounded-lg text-sm font-medium">{h}h</span>
      <span className="glass-panel px-3 py-1 rounded-lg text-sm font-medium">{m}m</span>
      <span className="glass-panel px-3 py-1 rounded-lg text-sm font-medium text-gradient">{sc}s</span>
    </div>
  );
}

async function fetchEpoch(){
  const p = kaiaProvider();
  const v = new ethers.Contract(addr.vault, VaultABI, p);
  const [e0, e1] = await v.epochInfo().catch(()=>[0,0]);
  return { epoch: Number(e0), nextAt: Number(e1)*1000 };
}

export function Epoch(){
  const { data } = useSWR("epoch", fetchEpoch, { refreshInterval: 10000 });
  return (
    <Card title="Epoch Information">
      <div className="space-y-3">
        <div>
          <span className="text-sm text-pendle-gray-400">Current Epoch</span>
          <div className="text-2xl font-bold text-gradient mt-1">{data?.epoch ?? "-"}</div>
        </div>
        <div>
          <span className="text-sm text-pendle-gray-400">Next Epoch In</span>
          {data?.nextAt ? <Countdown nextAt={data.nextAt}/> : <div className="text-sm mt-1">-</div>}
        </div>
        <div className="glass-panel p-3 rounded-lg space-y-1 mt-4">
          <div className="flex justify-between text-xs">
            <span className="text-pendle-gray-400">Deposit Fee</span>
            <span className="text-emerald-400 font-medium">0%</span>
          </div>
          <div className="flex justify-between text-xs">
            <span className="text-pendle-gray-400">Withdrawal Fee</span>
            <span className="text-yellow-400 font-medium">0.5%</span>
          </div>
          <div className="flex justify-between text-xs">
            <span className="text-pendle-gray-400">Rollover</span>
            <span className="font-medium">Weekly</span>
          </div>
        </div>
      </div>
    </Card>
  );
}