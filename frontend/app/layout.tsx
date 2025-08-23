import "./globals.css";
import Link from "next/link";
import { WalletConnect } from "@/components/WalletConnect";

export const metadata = { title: "ReKaUSD Dashboard", description: "KAIA ↔ ETH ReKaUSD protocol monitor" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <div className="mx-auto max-w-7xl p-6">
          <header className="flex items-center justify-between mb-6">
            <h1 className="text-2xl font-semibold">ReKaUSD Dashboard</h1>
            <div className="flex items-center gap-4">
              <nav className="flex gap-4 text-sm text-gray-300">
                <Link href="/">Overview</Link>
                <Link href="/kaia">KAIA Vault</Link>
                <Link href="/eth">ETH Strategy</Link>
                <Link href="/bridge">Bridge</Link>
              </nav>
              <WalletConnect />
            </div>
          </header>
          {children}
          <footer className="mt-10 text-xs text-gray-400">© ReKaUSD</footer>
        </div>
      </body>
    </html>
  );
}
