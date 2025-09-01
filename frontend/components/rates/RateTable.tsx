"use client";
import { useAppConfig } from "@/hooks/useAppConfig";

export function RateTable(){
  const cfg = useAppConfig();
  const rows = (cfg?.yieldSources ?? []).slice().sort((a,b)=> (b.apyBps||0)-(a.apyBps||0));
  
  if (!rows.length) return null;
  
  return (
    <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
      <div className="text-sm font-medium">Rate Comparison</div>
      <div className="mt-2 text-xs text-gray-400">Config-driven demo; not fetched live.</div>
      <div className="mt-3 divide-y divide-white/10">
        {rows.map((r,i)=>(
          <div key={i} className="py-2 flex items-center justify-between">
            <div className="text-sm">{r.name}</div>
            <div className="text-sm font-semibold">{(r.apyBps/100).toFixed(2)}%</div>
          </div>
        ))}
      </div>
    </div>
  );
}