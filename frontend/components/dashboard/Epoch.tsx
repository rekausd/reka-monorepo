"use client";
import React from "react";
import { COPY } from "@/lib/copy";
import { epochNow } from "@/lib/epoch";

export function Epoch(){
  const [now, setNow] = React.useState(()=>Date.now());
  React.useEffect(()=>{ 
    const id=setInterval(()=>setNow(Date.now()),1000); 
    return ()=>clearInterval(id); 
  },[]);
  
  const { epoch, end, remainingMs } = epochNow();
  
  // Calculate progress
  const totalMs = 10*24*3600*1000; // 10 days in ms
  const start = end - totalMs;
  const prog = Math.min(1, Math.max(0, (now - start)/totalMs));
  
  // Time remaining
  const s=Math.floor(remainingMs/1000);
  const d=Math.floor(s/86400);
  const h=Math.floor((s%86400)/3600);
  const m=Math.floor((s%3600)/60);
  
  return (
    <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
      <div className="flex items-center justify-between">
        <div className="text-xs text-gray-400">Epoch #{epoch}</div>
        <div className="text-xs text-gray-400">Ends in: {d}d {h}h {m}m</div>
      </div>
      <div className="mt-2 h-2 w-full bg-white/10 rounded-full overflow-hidden">
        <div 
          className="h-2 bg-gradient-to-r from-indigo-500 to-purple-500 rounded-full transition-all duration-500" 
          style={{width: `${prog*100}%`}}
        />
      </div>
      <div className="mt-2 text-[11px] text-gray-500">{COPY.epochNote}</div>
    </div>
  );
}