"use client";
import Link from "next/link";
import { WalletConnect } from "@/components/WalletConnect";

export function Header(){
  return (
    <header className="glass-panel px-6 py-4 mb-8 rounded-2xl backdrop-blur-md">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gradient">ReKaUSD</h1>
        <div className="flex items-center gap-6">
          <nav className="flex gap-6 text-sm">
            <Link href="/" className="nav-link">Dashboard</Link>
            <Link href="/app/stake" className="nav-link">Stake</Link>
            <Link href="/app/faucet" className="nav-link">Faucet</Link>
          </nav>
          <div className="pl-6 border-l border-pendle-gray-700">
            <WalletConnect />
          </div>
        </div>
      </div>
    </header>
  );
}