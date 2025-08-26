"use client";
import { StakeBox } from "@/components/stake/StakeBox";

export default function Page(){
  return (
    <div className="max-w-2xl mx-auto">
      <div className="card p-8 rounded-2xl">
        <h2 className="text-2xl font-bold text-gradient mb-6">Stake USDT</h2>
        <StakeBox />
      </div>
    </div>
  );
}