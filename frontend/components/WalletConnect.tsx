"use client";
import { useState } from "react";
import { connectKaiaWallet } from "@/lib/kaia";
import { connectKlip } from "@/lib/klip";

export function WalletConnect(){
  const [addr, setAddr] = useState<string>("");
  const [err, setErr] = useState<string>("");

  const onKaia = async ()=>{
    setErr("");
    try{ const c = await connectKaiaWallet(); setAddr(c.address); }
    catch(e:any){ setErr(e?.message ?? String(e)); }
  };
  const onKlip = async ()=>{
    setErr("");
    try{ const c = await connectKlip(); setAddr(c.address); }
    catch(e:any){ setErr(e?.message ?? String(e)); }
  };

  return (
    <div className="flex items-center gap-2">
      <button onClick={onKaia} className="px-3 py-1 rounded bg-emerald-600 hover:bg-emerald-700 text-sm">Connect KAIA Wallet</button>
      <button onClick={onKlip} className="px-3 py-1 rounded bg-sky-600 hover:bg-sky-700 text-sm">Connect Klip</button>
      {addr && <span className="ml-2 text-xs text-gray-300">Connected: <span className="font-mono">{addr}</span></span>}
      {err && <span className="ml-2 text-xs text-red-400">{err}</span>}
    </div>
  );
}
