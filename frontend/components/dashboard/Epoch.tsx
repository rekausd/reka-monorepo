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
  return <div className="text-sm text-gray-300">{d}d {h}h {m}m {sc}s</div>;
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
    <Card title="Epoch">
      <div>Current Epoch: {data?.epoch ?? "-"}</div>
      <div className="mt-1">{data?.nextAt ? <Countdown nextAt={data.nextAt}/> : "-"}</div>
      <div className="text-xs text-gray-400 mt-2">Deposit fee: 0% · Withdrawal fee: 0.5% · Rollover weekly</div>
    </Card>
  );
}