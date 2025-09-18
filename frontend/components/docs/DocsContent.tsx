"use client";
import { useState } from "react";
import { useAppConfig } from "@/hooks/useAppConfig";

function Mono({ children }: { children: React.ReactNode }) {
  return <span className="font-mono text-gray-300 break-all">{children}</span>;
}

function CopyBtn({ value }: { value: string }) {
  const [copied, setCopied] = useState(false);
  if (!value) return null;
  return (
    <button
      onClick={async () => {
        try {
          await navigator.clipboard.writeText(value);
          setCopied(true);
          setTimeout(() => setCopied(false), 1200);
        } catch {}
      }}
      className="ml-2 px-2 py-0.5 text-[10px] rounded border border-white/20 hover:border-white/40 text-gray-300 hover:text-white"
      title="Copy to clipboard"
    >
      {copied ? "Copied" : "Copy"}
    </button>
  );
}

export function DocsContent() {
  const cfg = useAppConfig();
  const explorer = "https://kairos.kaiascan.io";
  const short = (a?: string) => (a && a.length > 10 ? `${a.slice(0,6)}...${a.slice(-4)}` : a || "");
  
  return (
    <div className="space-y-6">
      <section className="bg-white/5 border border-white/10 p-4 rounded-2xl">
        <h2 className="text-xl font-bold mb-2">What is ReKaUSD?</h2>
        <p className="text-sm text-gray-300">
          ReKaUSD lets you deposit USDT on KAIA testnet and receive rkUSDT, a receipt token
          that represents your staked USDT. Strategies deploy the underlying capital to earn
          yield. When you withdraw, rkUSDT is redeemed back to USDT (subject to epoch timing).
        </p>
      </section>

      <section className="bg-white/5 border border-white/10 p-4 rounded-2xl space-y-2">
        <h3 className="text-base font-semibold">Tokens</h3>
        <ul className="text-sm text-gray-300 list-disc pl-5 space-y-1">
          <li><span className="font-semibold">USDT</span>: The stablecoin you deposit.</li>
          <li><span className="font-semibold">rkUSDT</span>: Receipt token minted 1:1 at deposit. You hold this during staking.</li>
        </ul>
      </section>

      <section className="bg-white/5 border border-white/10 p-4 rounded-2xl space-y-2">
        <h3 className="text-base font-semibold">How it works</h3>
        <ol className="text-sm text-gray-300 list-decimal pl-5 space-y-1">
          <li><span className="font-semibold">Deposit</span>: Approve via Permit2 (or fallback approve) and call deposit. You receive rkUSDT.</li>
          <li><span className="font-semibold">Earning</span>: The vault/strategy allocates capital to generate yield over epochs.</li>
          <li><span className="font-semibold">Withdraw</span>: Request withdrawal; it gets queued for the next epoch. Then claim to receive USDT back.</li>
        </ol>
        <p className="text-xs text-gray-400">
          Note: 1 rkUSDT = 1 USDT at mint; yield is realized on withdrawal via strategy accounting.
        </p>
      </section>

      {/* Quick Links */}
      <section className="bg-white/5 border border-white/10 p-4 rounded-2xl space-y-3">
        <h3 className="text-base font-semibold">Quick Links</h3>
        <div className="flex gap-2 flex-wrap">
          <a href="/app" className="px-3 py-2 text-xs rounded bg-white/10 hover:bg-white/20">Open App</a>
          <a href="/app#faucet" className="px-3 py-2 text-xs rounded bg-white/10 hover:bg-white/20">Open Faucet</a>
          {cfg?.vault && (
            <a target="_blank" rel="noreferrer" href={`${explorer}/address/${cfg.vault}`} className="px-3 py-2 text-xs rounded bg-white/10 hover:bg-white/20">Vault on Explorer</a>
          )}
          {cfg?.usdt && (
            <a target="_blank" rel="noreferrer" href={`${explorer}/address/${cfg.usdt}`} className="px-3 py-2 text-xs rounded bg-white/10 hover:bg-white/20">USDT on Explorer</a>
          )}
          {cfg?.rkUSDT && (
            <a target="_blank" rel="noreferrer" href={`${explorer}/address/${cfg.rkUSDT}`} className="px-3 py-2 text-xs rounded bg-white/10 hover:bg-white/20">rkUSDT on Explorer</a>
          )}
        </div>
      </section>

      <section className="bg-white/5 border border-white/10 p-4 rounded-2xl space-y-2">
        <h3 className="text-base font-semibold">Runtime Config</h3>
        {!cfg ? (
          <div className="text-sm text-gray-400">Loading configuration…</div>
        ) : (
          <div className="text-sm text-gray-300 space-y-1">
            <div>
              KAIA RPC: <Mono>{cfg.kaiaRpc}</Mono>
              <CopyBtn value={cfg.kaiaRpc} />
            </div>
            <div>
              USDT: <Mono>{cfg.usdt || "(not set)"}</Mono>
              {cfg.usdt && <CopyBtn value={cfg.usdt} />}
              {cfg.usdt && (
                <a target="_blank" rel="noreferrer" className="ml-2 text-xs text-indigo-300 hover:text-indigo-200" href={`${explorer}/address/${cfg.usdt}`}>{short(cfg.usdt)} ↗</a>
              )}
            </div>
            <div>
              rkUSDT: <Mono>{cfg.rkUSDT || "(not set)"}</Mono>
              {cfg.rkUSDT && <CopyBtn value={cfg.rkUSDT} />}
              {cfg.rkUSDT && (
                <a target="_blank" rel="noreferrer" className="ml-2 text-xs text-indigo-300 hover:text-indigo-200" href={`${explorer}/address/${cfg.rkUSDT}`}>{short(cfg.rkUSDT)} ↗</a>
              )}
            </div>
            <div>
              Vault: <Mono>{cfg.vault || "(not set)"}</Mono>
              {cfg.vault && <CopyBtn value={cfg.vault} />}
              {cfg.vault && (
                <a target="_blank" rel="noreferrer" className="ml-2 text-xs text-indigo-300 hover:text-indigo-200" href={`${explorer}/address/${cfg.vault}`}>{short(cfg.vault)} ↗</a>
              )}
            </div>
            <div>
              Permit2: <Mono>{cfg.permit2 || "(not set)"}</Mono>
              {cfg.permit2 && <CopyBtn value={cfg.permit2} />}
            </div>
          </div>
        )}
        <p className="text-xs text-gray-500 mt-2">
          These values load from <Mono>/reka-config.json</Mono> at runtime (with env fallbacks for local dev).
        </p>
      </section>

      <section className="bg-white/5 border border-white/10 p-4 rounded-2xl space-y-2">
        <h3 className="text-base font-semibold">Permit2</h3>
        <p className="text-sm text-gray-300">
          ReKaUSD prefers Permit2 for gas-efficient approvals. If the vault lacks a Permit2 path,
          the app falls back to the standard approve + deposit flow.
        </p>
      </section>

      <section className="bg-white/5 border border-white/10 p-4 rounded-2xl space-y-2">
        <h3 className="text-base font-semibold">Testnet & Faucet</h3>
        <p className="text-sm text-gray-300">
          On Kairos testnet, a mock USDT faucet is available to quickly get demo funds for testing.
          Use the Faucet section in the app to mint test USDT to your address.
        </p>
      </section>

      <section className="bg-white/5 border border-white/10 p-4 rounded-2xl space-y-2">
        <h3 className="text-base font-semibold">Notes</h3>
        <ul className="text-sm text-gray-300 list-disc pl-5 space-y-1">
          <li>Epoch-based withdrawals mean claims become available after the epoch boundary.</li>
          <li>Addresses and RPC are loaded at runtime from the public config.</li>
          <li>This is a testnet demo; contracts and behavior may change.</li>
        </ul>
      </section>
    </div>
  );
}

