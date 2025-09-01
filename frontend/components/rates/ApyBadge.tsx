"use client";
import { useAppConfig } from "@/hooks/useAppConfig";

export function ApyBadge({ className="" }:{ className?: string }){
  const cfg = useAppConfig();
  const bps = cfg?.strategyApyBps ?? 1100;
  const pct = (bps/100).toFixed(2);
  return (
    <span className={`inline-flex items-center rounded-full border border-white/10 bg-white/5 px-2 py-1 text-[11px] ${className}`}>
      Live APY (sim): <b className="ml-1">{pct}%</b>
    </span>
  );
}