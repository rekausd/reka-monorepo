"use client";
import { Card } from "@/components/Card";
import React from "react";
import { epochNow } from "@/lib/epoch";

function Countdown({ ms }:{ ms:number }){
  const [left, setLeft] = React.useState(ms);
  React.useEffect(()=>{ 
    const id = setInterval(()=>setLeft((p)=>Math.max(0,p-1000)), 1000); 
    return ()=>clearInterval(id); 
  },[]);
  const s = Math.floor(left/1000), d=Math.floor(s/86400), h=Math.floor((s%86400)/3600), m=Math.floor((s%3600)/60), sc=s%60;
  return (
    <div className="flex gap-2 mt-2">
      <span className="glass-panel px-3 py-1 rounded-lg text-sm font-medium">{d}d</span>
      <span className="glass-panel px-3 py-1 rounded-lg text-sm font-medium">{h}h</span>
      <span className="glass-panel px-3 py-1 rounded-lg text-sm font-medium">{m}m</span>
      <span className="glass-panel px-3 py-1 rounded-lg text-sm font-medium text-gradient">{sc}s</span>
    </div>
  );
}

export function Epoch(){
  const { epoch, end, remainingMs } = epochNow();
  return (
    <Card title="Epoch (10 days)">
      <div className="space-y-3">
        <div>
          <span className="text-sm text-pendle-gray-400">Current Epoch</span>
          <div className="text-2xl font-bold text-gradient mt-1">#{epoch}</div>
        </div>
        <div>
          <span className="text-sm text-pendle-gray-400">Ends in</span>
          <Countdown ms={remainingMs}/>
        </div>
        <div className="glass-panel p-3 rounded-lg space-y-2 mt-4">
          <div className="text-xs text-pendle-gray-400">
            Settlement and withdrawals are processed at each epoch boundary.
          </div>
          <div className="flex justify-between text-xs">
            <span className="text-pendle-gray-400">Deposit Fee</span>
            <span className="text-emerald-400 font-medium">0%</span>
          </div>
          <div className="flex justify-between text-xs">
            <span className="text-pendle-gray-400">Withdrawal Fee</span>
            <span className="text-yellow-400 font-medium">0.5%</span>
          </div>
          <div className="flex justify-between text-xs">
            <span className="text-pendle-gray-400">Epoch Duration</span>
            <span className="font-medium">10 days</span>
          </div>
        </div>
      </div>
    </Card>
  );
}