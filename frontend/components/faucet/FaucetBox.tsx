"use client";
import { useMemo, useState } from "react";
import { ethers } from "ethers";
import { useToast } from "@/components/Toast";
import { detectInjectedKaia } from "@/lib/wallet";
import { useAppConfig } from "@/hooks/useAppConfig";
import { ERC20 } from "@/lib/contracts";

const ABI = [
  ...ERC20,
  "function mint(address to, uint256 amount)"
];

export function FaucetBox() {
  const cfg = useAppConfig();
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState("");
  const { node: toast, showOk, showErr } = useToast();

  const inj = detectInjectedKaia();
  const provider = useMemo(() => inj ? new ethers.BrowserProvider(inj, "any") : null, [inj]);
  const signerP = useMemo(() => provider ? provider.getSigner() : null, [provider]);

  async function onMint() {
    if (!cfg) { 
      setMsg("Loading config..."); 
      return; 
    }
    
    const signer = await signerP;
    if (!signer) { 
      setMsg("Connect KAIA Wallet first."); 
      return; 
    }
    
    setBusy(true); 
    setMsg("");

    try {
      const me = await signer.getAddress();
      const tokenAddr = cfg.faucetToken && cfg.faucetToken.length > 0 ? cfg.faucetToken : cfg.usdt;
      
      if (!tokenAddr || tokenAddr === "") {
        throw new Error("No token address configured for faucet");
      }
      
      const c = new ethers.Contract(tokenAddr, ABI, signer);
      const decimals = await c.decimals().catch(() => 6);
      const whole = Number(cfg.faucetAmount || "10000");
      const amt = BigInt(Math.round(whole * 10 ** Number(decimals)));

      // Single, simple mint(to, amount) call
      showOk(`Minting ${whole.toLocaleString()} USDT...`);
      const tx = await c.mint(me, amt);
      await tx.wait();

      showOk(`✅ Minted ${whole.toLocaleString()} USDT`);
      setMsg(`Success! mint(to, amount) on ${tokenAddr.slice(0, 10)}...`);
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
      
      <div className="glass-panel p-4 rounded-xl">
        <div className="text-sm text-pendle-gray-400 mb-2">
          Mint {cfg?.faucetAmount || "10,000"} test USDT to your KAIA address.
        </div>
        <div className="text-xs text-pendle-gray-500">
          This faucet works with mock USDT deployed on KAIA testnet.
        </div>
      </div>

      <button 
        onClick={onMint} 
        disabled={busy || !cfg} 
        className="btn-primary w-full py-3 disabled:opacity-50 disabled:cursor-not-allowed"
      >
        {busy ? "Minting..." : "Get Mock USDT"}
      </button>
      
      {msg && (
        <div className="glass-panel p-3 rounded-lg">
          <div className="text-xs text-pendle-gray-400 break-all">{msg}</div>
        </div>
      )}
      
      {cfg && cfg.faucetToken && (
        <div className="text-xs text-pendle-gray-500">
          <div>Token: <span className="font-mono text-pendle-gray-400">{cfg.faucetToken}</span></div>
          <div>Amount: <span className="text-pendle-gray-400">{cfg.faucetAmount || "10000"} USDT</span></div>
          <div className="mt-2 text-pendle-gray-600">Using simplified mint(to, amount) signature</div>
        </div>
      )}
    </div>
  );
}