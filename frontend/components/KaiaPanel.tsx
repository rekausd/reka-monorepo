"use client";
import useSWR from "swr";
import { ethers } from "ethers";
import { addr, prov, VaultABI } from "@/lib/contracts";
import { Card } from "./Card";
import { EpochCountdown } from "./parts/EpochCountdown";

async function fetchKaia(){
  const v = new ethers.Contract(addr.vault, VaultABI, prov("kaia"));
  const [ep, due] = await Promise.all([v.epochInfo(), v.canRollover()]);
  return { epoch: Number(ep[0]), nextAt: Number(ep[1])*1000, due: Boolean(due) };
}

export function KaiaPanel(){
  const { data } = useSWR("kaia", fetchKaia, { refreshInterval: 10_000 });
  return (
    <div className="grid md:grid-cols-2 gap-5">
      <Card title="KAIA Vault — Epoch">
        <div>Epoch #{data?.epoch ?? 0}</div>
        <EpochCountdown nextAt={data?.nextAt ?? 0}/>
        <div className="text-xs text-gray-400 mt-2">{data?.due ? "Rollover due" : "Not due"}</div>
      </Card>
      <Card title="Notes">
        <ul className="list-disc pl-5 text-sm text-gray-300">
          <li>Deposit fee: 0</li>
          <li>Withdrawal fee: 0.5%</li>
          <li>Instant withdraws only for same-epoch deposits</li>
        </ul>
      </Card>
    </div>
  );
}
