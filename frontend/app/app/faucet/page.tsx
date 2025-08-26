"use client";
import { FaucetBox } from "@/components/faucet/FaucetBox";

export default function Page(){
  return (
    <div className="max-w-xl mx-auto">
      <div className="card p-8 rounded-2xl">
        <h2 className="text-2xl font-bold text-gradient mb-6">USDT Faucet</h2>
        <FaucetBox />
      </div>
    </div>
  );
}