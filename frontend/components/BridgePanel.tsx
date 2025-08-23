"use client";
import useSWR from "swr";
import { Card } from "./Card";

export function BridgePanel(){
  const url = process.env.NEXT_PUBLIC_BRIDGE_HEALTH_URL!;
  const { data } = useSWR(url, (u)=>fetch(u).then(r=>r.json()), { refreshInterval: 5000 });

  return (
    <div className="grid md:grid-cols-2 gap-5">
      <Card title="Bridge Health / Cursors">
        {!data ? <div className="text-gray-500 text-sm">Loading…</div> :
          <pre className="text-xs whitespace-pre-wrap">{JSON.stringify(data,null,2)}</pre>}
      </Card>
      <Card title="Notes">
        <ul className="list-disc pl-5 text-sm text-gray-300">
          <li>Service polls both chains every 5s.</li>
          <li>Idempotent mint: processed event IDs are stored in SQLite.</li>
          <li>Use /healthz for quick status.</li>
        </ul>
      </Card>
    </div>
  );
}
