"use client";
import Link from "next/link";
import { WalletConnect } from "@/components/WalletConnect";

export function Header(){
  return (
    <header className="flex items-center justify-between mb-6">
      <h1 className="text-2xl font-semibold">ReKaUSD (KAIA)</h1>
      <div className="flex items-center gap-4">
        <nav className="flex gap-4 text-sm text-gray-300">
          <Link href="/">Dashboard</Link>
          <Link href="/app/stake">Stake</Link>
          <Link href="/app/faucet">Faucet</Link>
        </nav>
        <WalletConnect />
      </div>
    </header>
  );
}