"use client";
import useSWR from "swr";
import { useAppConfig } from "@/hooks/useAppConfig";
import { fetchCCIPStats } from "@/lib/ccipRead";

function fmt(n: number) {
  return n.toLocaleString(undefined, { maximumFractionDigits: 2 });
}

export function CCIPPanel() {
  const cfg = useAppConfig();
  const maxItems = cfg?.ccipPanelMaxItems ?? 10;

  const { data } = useSWR(
    cfg ? ["ccip", cfg.ethRpc, cfg.sepoliaReceiver, maxItems] : null,
    () => fetchCCIPStats(cfg!, maxItems),
    { refreshInterval: 15000 }
  );

  if (!cfg) return null;

  return (
    <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
      <div className="flex items-center justify-between">
        <div className="text-sm font-medium">CCIP Status (Sepolia Receiver)</div>
        <CCIPBadge />
      </div>
      {!data ? (
        <div className="text-xs text-gray-400 mt-2">Loading CCIP stats…</div>
      ) : (
        <>
          <div className="mt-2 grid grid-cols-2 gap-3 text-sm">
            <div className="rounded bg-white/5 px-3 py-2">
              <div className="text-xs text-gray-400">Total messages</div>
              <div className="font-semibold">{data.count.toLocaleString()}</div>
            </div>
            <div className="rounded bg-white/5 px-3 py-2">
              <div className="text-xs text-gray-400">Total amount (raw)</div>
              <div className="font-semibold">{fmt(Number(data.totalAmount))}</div>
            </div>
          </div>
          <div className="mt-3">
            <div className="text-xs text-gray-400 mb-2">Recent</div>
            <div className="space-y-2">
              {data.rows.map((r, i) => (
                <div
                  key={r.tx + i}
                  className="flex items-center justify-between text-xs bg-white/5 rounded px-3 py-2"
                >
                  <div className="truncate">
                    <div className="font-mono text-[11px] truncate">{r.tx}</div>
                    <div className="text-gray-400">{new Date(r.ts).toLocaleString()}</div>
                  </div>
                  <div className="text-right">
                    <div className="font-semibold">{fmt(Number(r.amount))}</div>
                    <div className="text-gray-400">{r.tokenTransfer ? "Token" : "Message"}</div>
                  </div>
                </div>
              ))}
              {data.rows.length === 0 && (
                <div className="text-xs text-gray-500">No messages yet.</div>
              )}
            </div>
          </div>
        </>
      )}
    </div>
  );
}

export function CCIPBadge() {
  return (
    <span className="inline-flex items-center gap-2 text-[11px] rounded-full border border-white/10 bg-white/5 px-2 py-1">
      <svg width="12" height="12" viewBox="0 0 24 24" className="opacity-80">
        <circle cx="12" cy="12" r="10" fill="none" stroke="currentColor" />
      </svg>
      Powered by <b>Chainlink CCIP</b>
    </span>
  );
}