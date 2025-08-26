"use client";
import { useMemo, useState, useEffect } from "react";
import { ethers } from "ethers";
import { addr, VaultABI, ERC20 } from "@/lib/contracts";
import { NumberFmt } from "@/components/Number";
import { useToast } from "@/components/Toast";
import { detectInjectedKaia } from "@/lib/wallet";
import { epochNow } from "@/lib/epoch";

export function WithdrawBox(){
  const { epoch, end } = epochNow();
  const [addr0, setAddr] = useState("");
  const [dec, setDec] = useState(6);
  const [rkBal, setRkBal] = useState<bigint>(0n);
  const [pendingAmt, setPendingAmt] = useState<bigint>(0n);
  const [pendingEpoch, setPendingEpoch] = useState<number>(0);
  const [claimableAmt, setClaimableAmt] = useState<bigint>(0n);
  const [amt, setAmt] = useState("");
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
    
    try {
      const vaultContract = new ethers.Contract(addr.vault, VaultABI, s);
      const rkusdt = new ethers.Contract(addr.rkUSDT, ERC20, s);
      
      const a = await s.getAddress(); 
      setAddr(a);
      
      const [d, rb] = await Promise.all([
        rkusdt.decimals().catch(()=>6),
        rkusdt.balanceOf(a).catch(()=>0n)
      ]);
      setDec(Number(d)); 
      setRkBal(rb);

      // Try to get pending withdrawal info
      try {
        const [amt, ep] = await vaultContract.pendingWithdrawal(a);
        setPendingAmt(amt); 
        setPendingEpoch(Number(ep));
      } catch {
        try {
          const [amt, ep] = await vaultContract.getPendingWithdrawal(a);
          setPendingAmt(amt); 
          setPendingEpoch(Number(ep));
        } catch {
          // Try alternative method names
          try {
            const amt = await vaultContract.pendingNext(a);
            setPendingAmt(amt);
            // We don't know the epoch, so assume current
            setPendingEpoch(epoch);
          } catch {
            // No pending data available
          }
        }
      }

      // Try to get claimable amount
      try {
        const claimable = await vaultContract.claimable(a);
        setClaimableAmt(claimable);
      } catch {
        // No claimable view available
      }
    } catch (e) {
      console.error("Error refreshing withdrawal data:", e);
    }
  }

  useEffect(()=>{ refresh(); }, [signer, epoch]);

  function parseAmt(): bigint {
    const v = Number(amt || "0");
    if (!isFinite(v) || v <= 0) return 0n;
    return BigInt(Math.round(v * 10 ** dec));
  }

  async function onRequest(){
    const s = await signer;
    if (!s) {
      showErr("Please connect your wallet first");
      return;
    }
    
    const v = parseAmt(); 
    if (v === 0n) {
      showErr("Please enter a valid amount");
      return;
    }
    
    if (v > rkBal) {
      showErr("Insufficient rkUSDT balance");
      return;
    }
    
    setBusy(true);
    try {
      const vaultContract = new ethers.Contract(addr.vault, VaultABI, s);
      
      // Try different method names in order
      let tx;
      try {
        tx = await vaultContract.requestWithdrawal(v);
      } catch {
        try {
          tx = await vaultContract.requestWithdraw(v);
        } catch {
          try {
            tx = await vaultContract.queueWithdrawal(v);
          } catch {
            try {
              tx = await vaultContract.requestRedeem(v);
            } catch (e) {
              throw new Error("Vault does not expose withdrawal request functions on this network");
            }
          }
        }
      }
      
      showOk("Processing withdrawal request...");
      await tx.wait();
      showOk(`Withdrawal requested! It will be claimable after epoch #${epoch} ends.`);
      setAmt("");
      await refresh();
    } catch(e: any) { 
      showErr(e?.shortMessage || e?.message || String(e)); 
    } finally { 
      setBusy(false); 
    }
  }

  async function onClaim(){
    const s = await signer;
    if (!s) {
      showErr("Please connect your wallet first");
      return;
    }
    
    setBusy(true);
    try {
      const vaultContract = new ethers.Contract(addr.vault, VaultABI, s);
      
      // Try different method names
      let tx;
      try {
        tx = await vaultContract.claimWithdrawal();
      } catch {
        try {
          tx = await vaultContract.claim();
        } catch {
          try {
            tx = await vaultContract.withdraw();
          } catch {
            try {
              tx = await vaultContract.claimRedeem();
            } catch (e) {
              throw new Error("Vault does not expose claim functions on this network");
            }
          }
        }
      }
      
      showOk("Processing claim...");
      await tx.wait();
      showOk("Withdrawal claimed successfully!");
      await refresh();
    } catch(e: any) { 
      showErr(e?.shortMessage || e?.message || String(e)); 
    } finally { 
      setBusy(false); 
    }
  }

  const rkNum = Number(rkBal)/10**dec;
  const pendNum = Number(pendingAmt)/10**dec;
  const claimNum = Number(claimableAmt)/10**dec;
  const canClaim = (claimableAmt > 0n) || (pendingAmt > 0n && pendingEpoch < epoch);

  return (
    <div className="space-y-5">
      {toast}
      
      {/* Balance Info */}
      <div className="glass-panel p-4 rounded-xl">
        <div className="text-sm text-pendle-gray-400 mb-1">Your rkUSDT Balance</div>
        <div className="text-xl font-bold text-gradient"><NumberFmt v={rkNum}/></div>
      </div>

      {/* Request Withdrawal */}
      <div className="space-y-3">
        <div className="text-sm font-medium text-pendle-gray-300">Request Withdrawal</div>
        <input 
          type="number" 
          min="0" 
          step="0.000001"
          placeholder="Amount of rkUSDT to withdraw" 
          className="input-glow w-full px-4 py-3 text-white placeholder-pendle-gray-500"
          value={amt} 
          onChange={e=>setAmt(e.target.value)} 
          disabled={busy}
        />
        <button 
          onClick={onRequest} 
          disabled={busy || parseAmt()===0n || rkBal < parseAmt()} 
          className="btn-gradient w-full py-3 rounded-xl font-medium disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200"
        >
          {busy ? "Processing..." : "Request Withdrawal"}
        </button>
      </div>

      {/* Pending & Claimable Info */}
      {(pendingAmt > 0n || claimableAmt > 0n) && (
        <div className="glass-panel p-4 rounded-xl space-y-3">
          {pendingAmt > 0n && (
            <div>
              <div className="text-sm text-pendle-gray-400">Pending Withdrawal</div>
              <div className="text-lg font-semibold">
                <NumberFmt v={pendNum}/> rkUSDT
                {pendingEpoch > 0 && (
                  <span className="text-xs text-pendle-gray-500 ml-2">
                    (Requested in epoch #{pendingEpoch})
                  </span>
                )}
              </div>
            </div>
          )}
          
          {claimableAmt > 0n && (
            <div>
              <div className="text-sm text-pendle-gray-400">Claimable Amount</div>
              <div className="text-lg font-semibold text-emerald-400">
                <NumberFmt v={claimNum}/> USDT
              </div>
            </div>
          )}
        </div>
      )}

      {/* Claim Button */}
      <button 
        onClick={onClaim} 
        disabled={busy || !canClaim} 
        className={`w-full py-3 rounded-xl font-medium transition-all duration-200 ${
          canClaim 
            ? "btn-emerald btn-gradient" 
            : "bg-pendle-gray-800 text-pendle-gray-500 cursor-not-allowed opacity-50"
        }`}
      >
        {busy ? "Processing..." : canClaim ? "Claim Withdrawal" : "No withdrawals to claim"}
      </button>

      {/* Info */}
      <div className="glass-panel p-3 rounded-lg">
        <p className="text-xs text-pendle-gray-400">
          Withdrawals are processed at epoch boundaries. Current epoch ends: {new Date(end).toUTCString()}
        </p>
      </div>
    </div>
  );
}