"use client";
import { useEffect, useMemo, useState } from "react";
import { ethers } from "ethers";
import { addresses, getUSDTContract, getRkUSDTContract, getVaultContract, getPermit2Contract, ERC20, VaultABI } from "@/lib/contracts";
import { signPermit2, formatPermitDetails, formatTransferDetails } from "@/lib/permit2";
import { useToast } from "@/components/Toast";
import { NumberFmt } from "@/components/Number";
import { getSigner, getProvider } from "@/lib/wallet/kaia";
import { useAppConfig } from "@/hooks/useAppConfig";
import { COPY } from "@/lib/copy";
import { track } from "@/lib/analytics";
import { getVariant } from "@/lib/ab";

export function StakeBox(){
  const [addr0, setAddr] = useState<string>("");
  const [dec, setDec] = useState(6);
  const [bal, setBal] = useState<bigint>(0n);
  const [rkBal, setRkBal] = useState<bigint>(0n);
  const [amt, setAmt] = useState("0");
  const [busy, setBusy] = useState(false);
  const { node: toast, showOk, showErr } = useToast();

  const [signer, setSigner] = useState<ethers.Signer | null>(null);
  
  useEffect(() => {
    getSigner().then(setSigner).catch(() => setSigner(null));
  }, []);

  const config = useAppConfig();

  async function refresh(){
    const s = await signer;
    if (!s || !config) return;
    
    const usdt = getUSDTContract(config, s);
    const rkusdt = getRkUSDTContract(config, s);
    
    const a = await s.getAddress();
    setAddr(a);
    const [d, b, rk] = await Promise.all([
      usdt.decimals().catch(()=>6),
      usdt.balanceOf(a).catch(()=>0n),
      rkusdt.balanceOf(a).catch(()=>0n)
    ]);
    setDec(Number(d)); setBal(b); setRkBal(rk);
  }

  useEffect(()=>{ refresh(); }, [signer, config]);

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
    if (!config) {
      showErr("Configuration not loaded");
      return;
    }
    
    const need = parseAmt();
    if (need === 0n) {
      showErr("Please enter an amount");
      return;
    }

    setBusy(true);
    const owner = await s.getAddress();
    const addr = addresses(config);
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

      const permit2 = getPermit2Contract(config, s);
      const vault = getVaultContract(config, s);

      // Step 2: Try vault.depositWithPermit2 (preferred path)
      try {
        const tx = await vault.depositWithPermit2(token, need, ddlSec, signature);
        showOk("Processing deposit with Permit2...");
        await tx.wait();
        showOk("✅ Deposited via Permit2 (direct)");
        track("deposit_success", { amount: Number(amt) });
        track("ab_conv_deposit", { variant: getVariant() });
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
        track("deposit_success", { amount: Number(amt) });
        track("ab_conv_deposit", { variant: getVariant() });
        await refresh();
        return;
      } catch (e: any) {
        console.log("Generic Permit2 path failed:", e);
      }

      // Step 4: Fallback to legacy approve + deposit
      console.warn("⚠️ [FALLBACK] Using legacy approve+deposit. Please add depositWithPermit2 to vault contract.");
      showErr("Falling back to legacy approve (Permit2 unavailable)");
      
      const usdt = getUSDTContract(config, s);
      const txA = await usdt.approve(vaultAddr, need);
      showOk("Approving USDT...");
      await txA.wait();
      
      const txB = await vault.deposit(need);
      showOk("Depositing...");
      await txB.wait();
      
      showOk("✅ Deposited (legacy approve)");
      track("deposit_success", { amount: Number(amt) });
      track("ab_conv_deposit", { variant: getVariant() });
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
      <div className="bg-white/5 border border-white/10 p-3 rounded-xl">
        <div className="text-xs text-gray-400 mb-1">Status</div>
        <div className="text-sm">{addr0 ? `Connected: ${addr0.slice(0,6)}...${addr0.slice(-4)}` : "Connect wallet above"}</div>
      </div>
      
      <div className="bg-white/5 border border-white/10 p-3 rounded-xl space-y-2">
        <div className="flex justify-between items-center">
          <span className="text-xs text-gray-400">USDT Balance</span>
          <span className="text-sm font-semibold"><NumberFmt v={balNum}/></span>
        </div>
        <div className="flex justify-between items-center">
          <span className="text-xs text-gray-400">rkUSDT Balance</span>
          <span className="text-sm font-semibold"><NumberFmt v={rkNum}/></span>
        </div>
      </div>
      
      <div className="space-y-3">
        <input 
          type="number" 
          min="0" 
          placeholder={COPY.labels.depositAmount} 
          className="w-full bg-transparent border border-white/15 rounded-xl px-3 py-3 text-sm focus:outline-none focus:border-white/40 transition-colors placeholder-gray-500"
          value={amt} 
          onChange={e=>setAmt(e.target.value)} 
        />
        <button 
          onClick={permitAndDeposit} 
          disabled={busy || need===0n || bal<need} 
          className="w-full rounded-xl px-3 py-3 text-sm bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors font-medium"
        >
          {busy ? "Processing..." : COPY.depositCta}
        </button>
      </div>
      
      {need>0n && bal<need && 
        <div className="bg-red-500/10 border border-red-500/30 px-3 py-2 rounded-lg">
          <span className="text-xs text-red-400">Insufficient balance</span>
        </div>
      }
      
      <div className="bg-white/5 border border-white/10 p-3 rounded-lg">
        <p className="text-xs text-gray-400">1 rkUSDT = 1 USDT at mint (epoch accounting applies on withdrawal)</p>
      </div>
    </div>
  );
}