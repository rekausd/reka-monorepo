"use client";
import { ConfigWrapper } from "@/components/ConfigWrapper";
import { StakeBox } from "@/components/stake/StakeBox";
import { WithdrawBox } from "@/components/stake/WithdrawBox";

export default function Page(){
  return (
    <ConfigWrapper>
      {(config) => (
        <div className="max-w-5xl mx-auto">
          <div className="grid md:grid-cols-2 gap-6">
            {/* Stake Card */}
            <div className="card p-8 rounded-2xl">
              <h2 className="text-2xl font-bold text-gradient mb-6">Stake USDT</h2>
              <StakeBox config={config} />
            </div>
            
            {/* Withdraw Card */}
            <div className="card p-8 rounded-2xl">
              <h2 className="text-2xl font-bold text-gradient mb-6">Withdraw</h2>
              <div className="text-xs text-pendle-gray-400 mb-4">Queue withdrawals for next epoch</div>
              <WithdrawBox config={config} />
            </div>
          </div>
        </div>
      )}
    </ConfigWrapper>
  );
}