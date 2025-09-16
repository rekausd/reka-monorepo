"use client";
import { useMemo, useState, useEffect } from "react";
import { ethers } from "ethers";
import { addresses, getVaultContract, getRkUSDTContract, VaultABI, ERC20 } from "@/lib/contracts";
import { NumberFmt } from "@/components/Number";
import { useToast } from "@/components/Toast";
import { useUnifiedWallet } from "@/hooks/useUnifiedWallet";
import { epochNow } from "@/lib/epoch";
import { useAppConfig } from "@/hooks/useAppConfig";
import { COPY } from "@/lib/copy";
import { track } from "@/lib/analytics";
import { addBalanceRefreshListener, triggerBalanceRefresh } from "@/lib/events";

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

  const { isConnected, connect, signer, address } = useUnifiedWallet();

  const config = useAppConfig();

  async function refresh(){
    if (!signer || !config || !address) return;

    try {
      const vaultContract = getVaultContract(config, signer);
      const rkusdt = getRkUSDTContract(config, signer);

      setAddr(address);
      
      const [d, rb] = await Promise.all([
        rkusdt.decimals().catch(()=>6),
        rkusdt.balanceOf(address).catch(()=>0n)
      ]);
      setDec(Number(d)); 
      setRkBal(rb);

      // Try to get pending withdrawal info
      try {
        const [amt, ep] = await vaultContract.pendingWithdrawal(address);
        setPendingAmt(amt);
        setPendingEpoch(Number(ep));
      } catch {
        try {
          const [amt, ep] = await vaultContract.getPendingWithdrawal(address);
          setPendingAmt(amt);
          setPendingEpoch(Number(ep));
        } catch {
          // Try alternative method names
          try {
            const amt = await vaultContract.pendingNext(address);
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
        const claimable = await vaultContract.claimable(address);
        setClaimableAmt(claimable);
      } catch {
        // No claimable view available
      }
    } catch (e) {
      console.error("Error refreshing withdrawal data:", e);
    }
  }

  useEffect(()=>{ refresh(); }, [signer, epoch, config, address]);
  useEffect(()=>{
    return addBalanceRefreshListener(() => { refresh(); });
  }, [signer, epoch, config, address]);

  function parseAmt(): bigint {
    const v = Number(amt || "0");
    if (!isFinite(v) || v <= 0) return 0n;
    return BigInt(Math.round(v * 10 ** dec));
  }

  async function onRequest(){
    if (!isConnected || !signer) {
      showErr("Connecting wallet...");
      try {
        await connect();
      } catch (err) {
        showErr("Failed to connect wallet");
        return;
      }
    }

    const s = signer;
    if (!s) {
      showErr("Unable to get wallet signer");
      return;
    }

    if (!config) {
      showErr("Configuration not loaded");
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
      const vaultContract = getVaultContract(config, s);
      
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
      track("withdraw_request", { amount: Number(amt||"0") });
      setAmt("");
      await refresh();
      triggerBalanceRefresh();
    } catch(e: any) { 
      showErr(e?.shortMessage || e?.message || String(e)); 
    } finally { 
      setBusy(false); 
    }
  }

  async function onClaim(){
    if (!isConnected || !signer) {
      showErr("Connecting wallet...");
      try {
        await connect();
      } catch (err) {
        showErr("Failed to connect wallet");
        return;
      }
    }

    const s = signer;
    if (!s) {
      showErr("Unable to get wallet signer");
      return;
    }

    if (!config) {
      showErr("Configuration not loaded");
      return;
    }
    
    setBusy(true);
    try {
      const vaultContract = getVaultContract(config, s);
      
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
      track("withdraw_claim");
      await refresh();
      triggerBalanceRefresh();
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

  if (!config) {
    return (
      <div className="space-y-3">
        <div className="bg-white/5 border border-white/10 p-3 rounded-xl">
          <div className="text-xs text-gray-400 mb-1">Status</div>
          <div className="text-sm font-medium animate-pulse">Loading configuration...</div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {toast}
      
      {/* Balance Info */}
      <div className="bg-white/5 border border-white/10 p-3 rounded-xl">
        <div className="text-xs text-gray-400 mb-1">Your rkUSDT Balance</div>
        <div className="text-lg font-bold"><NumberFmt v={rkNum}/></div>
      </div>

      {/* Request Withdrawal */}
      <div className="space-y-3">
        <div className="text-sm font-medium text-pendle-gray-300">Request Withdrawal</div>
        <input 
          type="number" 
          min="0" 
          step="0.000001"
          placeholder={COPY.labels.withdrawAmount} 
          className="w-full bg-transparent border border-white/15 rounded-xl px-3 py-3 text-sm focus:outline-none focus:border-white/40 transition-colors placeholder-gray-500"
          value={amt} 
          onChange={e=>setAmt(e.target.value)} 
          disabled={busy}
        />
        <button 
          onClick={onRequest} 
          disabled={busy || parseAmt()===0n || rkBal < parseAmt()} 
          className="w-full rounded-xl px-3 py-3 text-sm bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors font-medium"
        >
          {busy ? "Processing..." : COPY.withdrawTab}
        </button>
      </div>

      {/* Pending & Claimable Info */}
      {(pendingAmt > 0n || claimableAmt > 0n) && (
        <div className="bg-white/5 border border-white/10 p-3 rounded-xl space-y-3">
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
        className={`w-full py-3 rounded-xl text-sm font-medium transition-colors ${
          canClaim 
            ? "bg-emerald-600 hover:bg-emerald-700" 
            : "bg-gray-600 cursor-not-allowed opacity-50"
        }`}
      >
        {busy ? "Processing..." : canClaim ? "Claim Withdrawal" : "No withdrawals to claim"}
      </button>

      {/* Info */}
      <div className="bg-white/5 border border-white/10 p-3 rounded-lg">
        <p className="text-xs text-pendle-gray-400">
          Withdrawals are processed at epoch boundaries. Current epoch ends: {new Date(end).toUTCString()}
        </p>
      </div>
    </div>
  );
}
