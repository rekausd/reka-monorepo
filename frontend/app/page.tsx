"use client";
import { Totals } from "@/components/dashboard/Totals";
import { Epoch } from "@/components/dashboard/Epoch";
import { COPY } from "@/lib/copy";
import { ApyBadge } from "@/components/rates/ApyBadge";
import { EarningsEstimator } from "@/components/rates/EarningsEstimator";
import { RateTable } from "@/components/rates/RateTable";
import { HeroSection } from "@/components/HeroSection";
import { CCIPPanel } from "@/components/ccip/CCIPPanel";

export default function Page(){
  return (
    <div className="space-y-4">
      <HeroSection />
      <Totals />
      <div className="flex items-center gap-2">
        <ApyBadge />
      </div>
      <EarningsEstimator />
      <Epoch />
      <RateTable />
      <CCIPPanel />
      <div className="text-xs text-gray-400 text-center mt-6">{COPY.footerNote}</div>
    </div>
  );
}