"use client";
import { useState } from "react";
import { connectKaiaWallet } from "@/lib/wallet";
import { COPY } from "@/lib/copy";

export function WalletConnect(){
  const [addr, setAddr] = useState<string>("");
  const [err, setErr] = useState<string>("");

  const onConnect = async ()=>{
    setErr("");
    try{
      const c = await connectKaiaWallet();
      setAddr(c.address);
    }catch(e:any){ setErr(e?.message ?? String(e)); }
  };

  if (addr) {
    return (
      <div className="flex items-center gap-2 w-full">
        <div className="flex-1 bg-white/5 border border-white/10 rounded-xl px-3 py-2 flex items-center gap-2">
          <span className="text-xs text-gray-400">KAIA:</span>
          <span className="text-xs font-mono">{addr.slice(0,6)}...{addr.slice(-4)}</span>
        </div>
        <button 
          onClick={()=>setAddr("")} 
          className="px-3 py-2 rounded-xl bg-white/10 hover:bg-white/20 text-xs font-medium transition-colors"
        >
          {COPY.labels.disconnect}
        </button>
      </div>
    );
  }

  return (
    <div className="w-full">
      <button 
        onClick={onConnect} 
        className="w-full bg-indigo-600 hover:bg-indigo-700 text-white text-sm font-medium rounded-xl px-4 py-2.5 transition-colors"
      >
        {COPY.labels.connect}
      </button>
      {err && <div className="mt-2 text-xs text-red-400">{err}</div>}
    </div>
  );
}