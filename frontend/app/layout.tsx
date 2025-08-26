import "./globals.css";
import Link from "next/link";
import { Header } from "@/components/Header";

export const metadata = { title: "ReKaUSD (KAIA)", description: "Stake USDT → rkUSDT with external yield" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <div className="mx-auto max-w-7xl p-6">
          <Header />
          {children}
          <footer className="mt-10 text-xs text-gray-400">© ReKaUSD</footer>
        </div>
      </body>
    </html>
  );
}