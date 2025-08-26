"use client";
import { useMemo, useState } from "react";
import { ethers } from "ethers";
import { addr, ERC20 } from "@/lib/contracts";
import { useToast } from "@/components/Toast";
import { detectInjectedKaia } from "@/lib/wallet";

export function FaucetBox(){
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState("");
  const { node: toast, showOk, showErr } = useToast();

  const inj = detectInjectedKaia();
  const provider = useMemo(()=> inj ? new ethers.BrowserProvider(inj, "any") : null, [inj]);
  const signer = useMemo(async ()=> {
    if (!provider) return null;
    try { return await provider.getSigner(); } catch { return null; }
  }, [provider]);

  async function onMint(){
    const s = await signer;
    if (!s) { setMsg("Connect KAIA Wallet first."); return; }
    setBusy(true); setMsg("");
    try{
      const a = await s.getAddress();
      const usdt = new ethers.Contract(addr.kaiaUSDT, ERC20, s);
      const dec = await usdt.decimals().catch(()=>6);
      const amt = BigInt(10_000 * 10**Number(dec));

      // Try mint(address,uint256)
      try{
        const c = new ethers.Contract(addr.kaiaUSDT, [...ERC20, "function mint(address to, uint256 amount)"], s);
        const tx = await c.mint(a, amt); 
        await tx.wait(); 
        showOk("Minted 10,000 USDT"); 
        return;
      }catch{}

      // Fallback: mint(uint256)
      try{
        const c2 = new ethers.Contract(addr.kaiaUSDT, [...ERC20, "function mint(uint256 amount)"], s);
        const tx2 = await c2.mint(amt); 
        await tx2.wait();
        showOk("Minted 10,000 USDT");
        return;
      }catch{}

      // If both fail, show error
      throw new Error("Faucet function not found on USDT contract");
    }catch(e:any){ showErr(e?.shortMessage || e?.message || String(e)); }
    finally{ setBusy(false); }
  }

  return (
    <div className="space-y-3">
      {toast}
      <div className="text-sm text-gray-300">Mint 10,000 test USDT to your KAIA address.</div>
      <button onClick={onMint} disabled={busy} className="px-3 py-2 rounded bg-indigo-600 hover:bg-indigo-700 text-sm disabled:opacity-50">
        {busy ? "Minting..." : "Get Mock USDT"}
      </button>
      {msg && <div className="text-xs text-gray-400">{msg}</div>}
    </div>
  );
}