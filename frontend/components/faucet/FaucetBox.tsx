"use client";
import { useMemo, useState } from "react";
import { ethers } from "ethers";
import { useToast } from "@/components/Toast";
import { useUnifiedWallet } from "@/hooks/useUnifiedWallet";
import { useAppConfig } from "@/hooks/useAppConfig";
import { ERC20 } from "@/lib/contracts";
import { COPY } from "@/lib/copy";
import { track } from "@/lib/analytics";
import { getVariant } from "@/lib/ab";
import { triggerBalanceRefresh } from "@/lib/events";

const ABI = [
  ...ERC20,
  "function mint(address to, uint256 amount)"
];

export function FaucetBox() {
  const cfg = useAppConfig();
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState("");
  const { node: toast, showOk, showErr } = useToast();
  const { isConnected, connect, signer, provider } = useUnifiedWallet();

  async function onMint() {
    if (!cfg) {
      setMsg("Loading config...");
      return;
    }

    setBusy(true);
    setMsg("");

    try {
      // Resolve a signer; attempt auto-connect if needed
      let walletSigner = signer || (provider ? await provider.getSigner() : null);
      if (!walletSigner) {
        try {
          // Try to connect wallet on demand
          setMsg("Connecting wallet...");
          await connect();
        } catch {
          // ignore here; we will try injected provider next
        }
        // Try injected provider directly (KAIA/klaytn)
        const w = typeof window !== 'undefined' ? (window as any) : undefined;
        const injected = w && (w.kaia ?? w.klaytn);
        if (injected) {
          const browserProvider = new ethers.BrowserProvider(injected, 'any');
          walletSigner = await browserProvider.getSigner().catch(() => null as any);
        }
      }
      if (!walletSigner) throw new Error("Unable to get wallet signer");

      const me = await walletSigner.getAddress();
      const tokenAddr = cfg.faucetToken && cfg.faucetToken.length > 0 ? cfg.faucetToken : cfg.usdt;
      
      if (!tokenAddr || tokenAddr === "") {
        throw new Error("No token address configured for faucet");
      }
      
      const c = new ethers.Contract(tokenAddr, ABI, walletSigner);
      const decimals = await c.decimals().catch(() => 6);
      const whole = Number(cfg.faucetAmount || "10000");
      const amt = BigInt(Math.round(whole * 10 ** Number(decimals)));

      // Single, simple mint(to, amount) call
      showOk(`Minting ${whole.toLocaleString()} USDT...`);
      const tx = await c.mint(me, amt);
      await tx.wait();

      showOk(`✅ Minted ${whole.toLocaleString()} USDT`);
      setMsg(`Success! mint(to, amount) on ${tokenAddr.slice(0, 10)}...`);
      track("faucet_success", { amount: whole });
      track("ab_conv_faucet", { variant: getVariant() });
      // Notify other views (Stake/Withdraw) to refresh balances
      triggerBalanceRefresh();
    } catch (e: any) {
      const err = e?.shortMessage || e?.message || String(e);
      showErr(err);
      setMsg(`Failed: ${err.slice(0, 200)}`);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="space-y-4">
      {toast}
      
      <div className="bg-white/5 border border-white/10 p-3 rounded-xl">
        <div className="text-xs text-gray-400 mb-2">
          Mint {cfg?.faucetAmount || "10,000"} test USDT to your KAIA address.
        </div>
        <div className="text-xs text-gray-500">
          This faucet works with mock USDT deployed on KAIA testnet.
        </div>
      </div>

      <button 
        onClick={onMint} 
        disabled={busy || !cfg} 
        className="w-full rounded-xl px-3 py-3 text-sm bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors font-medium"
      >
        {busy ? "Minting..." : COPY.faucetCta}
      </button>
      
      {msg && (
        <div className="bg-white/5 border border-white/10 p-3 rounded-lg">
          <div className="text-xs text-gray-400 break-all">{msg}</div>
        </div>
      )}
      
      {cfg && cfg.faucetToken && (
        <div className="text-xs text-gray-500">
          <div>Token: <span className="font-mono text-gray-400">{cfg.faucetToken}</span></div>
          <div>Amount: <span className="text-gray-400">{cfg.faucetAmount || "10000"} USDT</span></div>
          <div className="mt-2 text-gray-600">Using simplified mint(to, amount) signature</div>
        </div>
      )}
    </div>
  );
}
