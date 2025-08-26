"use client";
import { useEffect, useMemo, useState } from "react";
import { ethers } from "ethers";
import { addr, ERC20, VaultABI } from "@/lib/contracts";
import { useToast } from "@/components/Toast";
import { NumberFmt } from "@/components/Number";
import { detectInjectedKaia } from "@/lib/wallet";

export function StakeBox(){
  const [addr0, setAddr] = useState<string>("");
  const [dec, setDec] = useState(6);
  const [bal, setBal] = useState<bigint>(0n);
  const [allow, setAllow] = useState<bigint>(0n);
  const [rkBal, setRkBal] = useState<bigint>(0n);
  const [amt, setAmt] = useState("0");
  const [busy, setBusy] = useState(false);
  const { node: toast, showOk, showErr } = useToast();

  const inj = detectInjectedKaia();
  const provider = useMemo(()=> inj ? new ethers.BrowserProvider(inj, "any") : null, [inj]);
  const signer = useMemo(async ()=> {
    if (!provider) return null;
    try { return await provider.getSigner(); } catch { return null; }
  }, [provider]);

  async function refresh(){
    const s = await signer;
    if (!s) return;
    
    const usdt = new ethers.Contract(addr.kaiaUSDT, ERC20, s);
    const rkusdt = new ethers.Contract(addr.rkUSDT, ERC20, s);
    
    const a = await s.getAddress();
    setAddr(a);
    const [d, b, alw, rk] = await Promise.all([
      usdt.decimals().catch(()=>6),
      usdt.balanceOf(a).catch(()=>0n),
      usdt.allowance(a, addr.vault).catch(()=>0n),
      rkusdt.balanceOf(a).catch(()=>0n)
    ]);
    setDec(Number(d)); setBal(b); setAllow(alw); setRkBal(rk);
  }

  useEffect(()=>{ refresh(); }, [signer]);

  function parseAmt(): bigint {
    const v = Number(amt || "0");
    if (!isFinite(v) || v <= 0) return 0n;
    return BigInt(Math.round(v * 10 ** dec));
  }

  async function onApprove(){
    const s = await signer;
    if (!s) return;
    const usdt = new ethers.Contract(addr.kaiaUSDT, ERC20, s);
    try{
      setBusy(true);
      const need = parseAmt();
      const tx = await usdt.approve(addr.vault, need);
      await tx.wait();
      showOk("Approved");
      await refresh();
    }catch(e:any){ showErr(e?.shortMessage || e?.message || String(e)); }
    finally{ setBusy(false); }
  }

  async function onDeposit(){
    const s = await signer;
    if (!s) return;
    const vault = new ethers.Contract(addr.vault, VaultABI, s);
    try{
      setBusy(true);
      const need = parseAmt();
      const tx = await vault.deposit(need);
      await tx.wait();
      showOk("Deposited");
      await refresh();
    }catch(e:any){ showErr(e?.shortMessage || e?.message || String(e)); }
    finally{ setBusy(false); }
  }

  const need = parseAmt();
  const hasAllow = allow >= need && need > 0n;
  const balNum = Number(bal)/10**dec;
  const rkNum = Number(rkBal)/10**dec;

  return (
    <div className="space-y-4">
      {toast}
      <div className="text-sm text-gray-300">{addr0 ? `Connected: ${addr0}` : "Connect KAIA Wallet via header"}</div>
      <div className="text-sm text-gray-300">USDT Balance: <b><NumberFmt v={balNum}/></b></div>
      <div className="flex items-center gap-3">
        <input type="number" min="0" placeholder="Amount" className="bg-transparent border rounded px-3 py-2 w-48 border-gray-600"
          value={amt} onChange={e=>setAmt(e.target.value)} />
        {!hasAllow ? (
          <button onClick={onApprove} disabled={busy || need===0n} className="px-3 py-2 rounded bg-indigo-600 hover:bg-indigo-700 text-sm disabled:opacity-50">Approve</button>
        ) : (
          <button onClick={onDeposit} disabled={busy || need===0n || bal<need} className="px-3 py-2 rounded bg-emerald-600 hover:bg-emerald-700 text-sm disabled:opacity-50">Deposit</button>
        )}
      </div>
      {need>0n && bal<need && <div className="text-xs text-red-400">Insufficient balance.</div>}
      <div className="text-sm text-gray-300">rkUSDT Balance: <b><NumberFmt v={rkNum}/></b></div>
      <div className="text-xs text-gray-400">1 rkUSDT = 1 USDT at mint (epoch accounting applies on withdrawal).</div>
    </div>
  );
}