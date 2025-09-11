"use client";
import Link from "next/link";
import Image from "next/image";
import { WalletConnect } from "@/components/WalletConnect";
import { COPY } from "@/lib/copy";
import { useMiniApp } from "@/lib/miniapp/init";

export function Header(){
  const { isInMiniApp } = useMiniApp();
  
  return (
    <header className={`border-b border-white/10 backdrop-blur-md ${isInMiniApp ? 'sticky top-0 z-50' : ''}`}>
      <div className="max-w-[480px] mx-auto px-4 py-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <Image src="/logo-mark.svg" alt="ReKaUSD" width={24} height={24} priority />
            <h1 className="text-lg font-bold">{COPY.appName}</h1>
            <span className="rounded px-1.5 py-0.5 text-[9px] bg-amber-500/20 text-amber-300">TESTNET</span>
          </div>
          <nav className="flex items-center gap-4">
            <Link href="/" className="text-sm text-gray-400 hover:text-white">Overview</Link>
            <Link href="/app" className="text-sm text-gray-400 hover:text-white">App</Link>
          </nav>
        </div>
        <div className="mt-2">
          <WalletConnect />
        </div>
      </div>
    </header>
  );
}
