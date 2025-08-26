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
      <div className="flex items-center gap-2">
        <span className="text-xs text-gray-300">KAIA: <span className="font-mono">{addr.slice(0,6)}...{addr.slice(-4)}</span></span>
        <button onClick={()=>setAddr("")} className="px-3 py-1 rounded bg-gray-700 hover:bg-gray-600 text-sm">Disconnect</button>
      </div>
    );
  }

  return (
    <div className="flex items-center gap-2">
      <button onClick={onConnect} className="px-3 py-1 rounded bg-emerald-600 hover:bg-emerald-700 text-sm">
        Connect KAIA Wallet
      </button>
      {err && <span className="ml-2 text-xs text-red-400">{err}</span>}
    </div>
  );
}