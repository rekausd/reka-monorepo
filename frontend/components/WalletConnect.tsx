"use client";
import { useState } from "react";
import { connectKaiaWallet } from "@/lib/wallet";

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
      <div className="flex items-center gap-3">
        <div className="glass-panel px-4 py-2 flex items-center gap-2">
          <span className="text-xs text-pendle-gray-400">KAIA:</span>
          <span className="text-xs font-mono text-gradient">{addr.slice(0,6)}...{addr.slice(-4)}</span>
        </div>
        <button 
          onClick={()=>setAddr("")} 
          className="px-4 py-2 rounded-xl bg-gradient-to-r from-pendle-gray-700 to-pendle-gray-600 hover:from-pendle-gray-600 hover:to-pendle-gray-500 text-sm font-medium transition-all duration-200 hover:shadow-lg"
        >
          Disconnect
        </button>
      </div>
    );
  }

  return (
    <div className="flex items-center gap-3">
      <button 
        onClick={onConnect} 
        className="btn-emerald btn-gradient text-sm font-medium rounded-xl px-5 py-2.5 shadow-lg"
      >
        Connect KAIA Wallet
      </button>
      {err && <span className="ml-2 text-xs text-red-400/80 backdrop-blur-sm">{err}</span>}
    </div>
  );
}