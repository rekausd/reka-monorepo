"use client";
import { FaucetBox } from "@/components/faucet/FaucetBox";
import { StakeBox } from "@/components/stake/StakeBox";
import { WithdrawBox } from "@/components/stake/WithdrawBox";
import { ApyBadge } from "@/components/rates/ApyBadge";
import { EarningsEstimator } from "@/components/rates/EarningsEstimator";

export default function AppPage(){
  return (
    <div className="space-y-4 pb-24"> {/* leave space for sticky bar */}
      <section id="faucet" className="rounded-2xl border border-white/10 bg-white/5 p-4">
        <div className="text-sm font-medium">Demo USDT</div>
        <div className="text-xs text-gray-400 mt-1">Get test USDT to try the parking account.</div>
        <div className="mt-3"><FaucetBox/></div>
      </section>

      <section id="deposit" className="rounded-2xl border border-white/10 bg-white/5 p-4">
        <div className="flex items-center justify-between mb-3">
          <div className="text-sm font-medium">Deposit</div>
          <ApyBadge />
        </div>
        <StakeBox/>
      </section>

      <section id="withdraw" className="rounded-2xl border border-white/10 bg-white/5 p-4">
        <div className="text-sm font-medium">Withdraw</div>
        <div className="mt-3"><WithdrawBox/></div>
      </section>

      <EarningsEstimator />

      {/* Sticky action bar */}
      <div className="fixed left-0 right-0 bottom-0 z-40 bg-[#0B0C10]/90 backdrop-blur border-t border-white/10">
        <div className="max-w-[480px] mx-auto px-4 py-3 grid grid-cols-3 gap-3">
          <a href="#faucet" className="text-center text-sm rounded bg-white/10 py-2 hover:bg-white/20 transition-colors">Faucet</a>
          <a href="#deposit" className="text-center text-sm rounded bg-indigo-600 py-2 hover:bg-indigo-700 transition-colors font-medium">Deposit</a>
          <a href="#withdraw" className="text-center text-sm rounded bg-white/10 py-2 hover:bg-white/20 transition-colors">Withdraw</a>
        </div>
      </div>
    </div>
  );
}