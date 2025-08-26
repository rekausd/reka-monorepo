"use client";
import { Totals } from "@/components/dashboard/Totals";
import { Epoch } from "@/components/dashboard/Epoch";
import { Holdings } from "@/components/dashboard/Holdings";
import { TVLChart } from "@/components/dashboard/TVLChart";

export default function Page(){
  return (
    <div className="space-y-6">
      <Totals />
      <div className="grid md:grid-cols-2 gap-5">
        <Epoch />
        <Holdings />
      </div>
      <div className="card p-5">
        <div className="text-sm text-gray-400 mb-2">TVL (sampled)</div>
        <TVLChart />
      </div>
    </div>
  );
}