"use client";
import { useEffect, useMemo, useState } from "react";
import { ethers } from "ethers";
import { addr, ERC20, VaultABI, Permit2ABI, PERMIT2_ADDR } from "@/lib/contracts";
import { signPermit2, formatPermitDetails, formatTransferDetails } from "@/lib/permit2";
import { useToast } from "@/components/Toast";
import { NumberFmt } from "@/components/Number";
import { detectInjectedKaia } from "@/lib/wallet";

export function StakeBox(){
  const [addr0, setAddr] = useState<string>("");
  const [dec, setDec] = useState(6);
  const [bal, setBal] = useState<bigint>(0n);
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
    const [d, b, rk] = await Promise.all([
      usdt.decimals().catch(()=>6),
      usdt.balanceOf(a).catch(()=>0n),
      rkusdt.balanceOf(a).catch(()=>0n)
    ]);
    setDec(Number(d)); setBal(b); setRkBal(rk);
  }

  useEffect(()=>{ refresh(); }, [signer]);

  function parseAmt(): bigint {
    const v = Number(amt || "0");
    if (!isFinite(v) || v <= 0) return 0n;
    return BigInt(Math.round(v * 10 ** dec));
  }

  async function permitAndDeposit(){
    const s = await signer;
    if (!s) {
      showErr("Please connect your wallet first");
      return;
    }
    
    const need = parseAmt();
    if (need === 0n) {
      showErr("Please enter an amount");
      return;
    }

    setBusy(true);
    const owner = await s.getAddress();
    const token = addr.kaiaUSDT;
    const vaultAddr = addr.vault;

    try {
      // Calculate permit expiration times
      const nowSec = Math.floor(Date.now() / 1000);
      const expSec = nowSec + 60 * 60 * 24 * 7; // 7 days expiration
      const ddlSec = nowSec + 60 * 10; // 10 minutes signature deadline

      // Step 1: Sign Permit2 EIP-712 message
      showOk("Please sign the Permit2 authorization...");
      const { signature } = await signPermit2(s, owner, token, vaultAddr, need, expSec, ddlSec);

      const permit2 = new ethers.Contract(PERMIT2_ADDR, Permit2ABI, s);
      const vault = new ethers.Contract(vaultAddr, VaultABI, s);

      // Step 2: Try vault.depositWithPermit2 (preferred path)
      try {
        const tx = await vault.depositWithPermit2(token, need, ddlSec, signature);
        showOk("Processing deposit with Permit2...");
        await tx.wait();
        showOk("✅ Deposited via Permit2 (direct)");
        await refresh();
        return;
      } catch (e: any) {
        console.log("depositWithPermit2 not available, trying generic path...");
      }

      // Step 3: Generic Permit2 path
      try {
        // 3a: Set permit on Permit2 contract
        const details = formatPermitDetails(token, need, expSec, 0);
        const tx1 = await permit2.permit(owner, details, vaultAddr, ddlSec, signature);
        showOk("Setting Permit2 authorization...");
        await tx1.wait();

        // 3b: Transfer tokens via Permit2
        const transferDetails = [formatTransferDetails(owner, vaultAddr, need, token)];
        const tx2 = await permit2.transferFrom(transferDetails);
        showOk("Transferring tokens...");
        await tx2.wait();

        // 3c: Call deposit to finalize (if needed)
        try {
          const tx3 = await vault.deposit(need);
          await tx3.wait();
        } catch {
          // Some vaults may auto-detect the transfer, so this is optional
        }

        showOk("✅ Deposited via Permit2 (generic)");
        await refresh();
        return;
      } catch (e: any) {
        console.log("Generic Permit2 path failed:", e);
      }

      // Step 4: Fallback to legacy approve + deposit
      console.warn("⚠️ [FALLBACK] Using legacy approve+deposit. Please add depositWithPermit2 to vault contract.");
      showErr("Falling back to legacy approve (Permit2 unavailable)");
      
      const usdt = new ethers.Contract(token, ERC20, s);
      const txA = await usdt.approve(vaultAddr, need);
      showOk("Approving USDT...");
      await txA.wait();
      
      const txB = await vault.deposit(need);
      showOk("Depositing...");
      await txB.wait();
      
      showOk("✅ Deposited (legacy approve)");
      await refresh();
    } catch (err: any) {
      showErr(err?.shortMessage || err?.message || String(err));
    } finally {
      setBusy(false);
    }
  }

  const need = parseAmt();
  const balNum = Number(bal)/10**dec;
  const rkNum = Number(rkBal)/10**dec;

  return (
    <div className="space-y-5">
      {toast}
      <div className="glass-panel p-4 rounded-xl">
        <div className="text-sm text-pendle-gray-400 mb-1">Status</div>
        <div className="text-sm font-medium">{addr0 ? `Connected: ${addr0.slice(0,6)}...${addr0.slice(-4)}` : "Connect KAIA Wallet via header"}</div>
      </div>
      
      <div className="glass-panel p-4 rounded-xl space-y-3">
        <div className="flex justify-between items-center">
          <span className="text-sm text-pendle-gray-400">USDT Balance</span>
          <span className="text-lg font-semibold text-gradient"><NumberFmt v={balNum}/></span>
        </div>
        <div className="flex justify-between items-center">
          <span className="text-sm text-pendle-gray-400">rkUSDT Balance</span>
          <span className="text-lg font-semibold text-gradient"><NumberFmt v={rkNum}/></span>
        </div>
      </div>
      
      <div className="space-y-3">
        <input 
          type="number" 
          min="0" 
          placeholder="Enter amount to stake" 
          className="input-glow w-full px-4 py-3 text-white placeholder-pendle-gray-500"
          value={amt} 
          onChange={e=>setAmt(e.target.value)} 
        />
        <button 
          onClick={permitAndDeposit} 
          disabled={busy || need===0n || bal<need} 
          className="btn-emerald btn-gradient w-full py-3 rounded-xl font-medium disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200"
        >
          {busy ? "Processing..." : "Permit & Deposit"}
        </button>
      </div>
      
      {need>0n && bal<need && 
        <div className="glass-panel px-3 py-2 rounded-lg border-red-500/30 border">
          <span className="text-xs text-red-400">Insufficient balance</span>
        </div>
      }
      
      <div className="glass-panel p-3 rounded-lg">
        <p className="text-xs text-pendle-gray-400">1 rkUSDT = 1 USDT at mint (epoch accounting applies on withdrawal)</p>
      </div>
    </div>
  );
}