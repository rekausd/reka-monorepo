"use client";
import { COPY } from "@/lib/copy";
import { useKaiaTotals } from "@/hooks/useKaiaStats";
import { AnimatedNumber } from "@/components/AnimatedNumber";
import { ShimmerBar } from "@/components/ShimmerBar";
import { Skeleton } from "@/components/Skeleton";

export function Totals(){
  const { totals } = useKaiaTotals();
  const val = totals ? Number(totals.rkSupply)/10**(totals.decR||6) : 0;

  return (
    <div className="space-y-4">
      {/* Hero balance card */}
      <div className="rounded-2xl border border-white/10 bg-white/5 p-5">
        <div className="text-xs text-gray-400">{COPY.balanceTitle}</div>
        <div className="mt-1 text-4xl md:text-5xl font-semibold">
          {!totals ? (
            <Skeleton h="48px" />
          ) : (
            <>
              <AnimatedNumber value={val} decimals={2} />
              <span className="ml-2 text-base text-gray-400">rkUSDT</span>
            </>
          )}
        </div>
        <div className="mt-3"><ShimmerBar/></div>
        <div className="mt-2 text-xs text-gray-400">{COPY.balanceDesc}</div>
      </div>

      {/* Two small info cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
          <div className="text-xs text-gray-400">{COPY.stakedCardTitle}</div>
          <div className="mt-1 text-2xl font-semibold">
            {!totals ? <Skeleton h="32px" /> : <AnimatedNumber value={val} />}
          </div>
        </div>
        <div className="rounded-2xl border border-white/10 bg-white/5 p-4">
          <div className="text-xs text-gray-400">{COPY.supplyCardTitle}</div>
          <div className="mt-1 text-2xl font-semibold">
            {!totals ? <Skeleton h="32px" /> : <AnimatedNumber value={val} />}
          </div>
        </div>
      </div>
    </div>
  );
}