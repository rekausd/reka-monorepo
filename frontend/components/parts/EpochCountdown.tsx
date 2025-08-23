"use client";
import { useEffect, useState } from "react";
export function EpochCountdown({ nextAt }:{ nextAt: number }) {
  const [left, setLeft] = useState( Math.max(0, nextAt - Date.now()) );
  useEffect(()=>{
    const id = setInterval(()=> setLeft(Math.max(0, nextAt - Date.now())), 1000);
    return ()=> clearInterval(id);
  },[nextAt]);
  const s = Math.floor(left/1000);
  const d = Math.floor(s/86400), h = Math.floor((s%86400)/3600), m = Math.floor((s%3600)/60), sc = s%60;
  return <div className="text-sm text-gray-300">{d}d {h}h {m}m {sc}s</div>;
}
