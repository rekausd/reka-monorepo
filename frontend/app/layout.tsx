import "./globals.css";
import Link from "next/link";
import { Header } from "@/components/Header";
import { Footer } from "@/components/Footer";

export const metadata = { title: "ReKaUSD (KAIA)", description: "Stake USDT → rkUSDT with external yield" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="h-full">
      <body className="min-h-screen h-full flex flex-col">
        {/* Header section */}
        <div className="mx-auto w-full max-w-7xl p-6 pb-0">
          <Header />
        </div>
        
        {/* Main content area - grows to fill available space */}
        <main className="flex-1">
          <div className="mx-auto max-w-7xl px-6 py-8">
            {children}
          </div>
        </main>
        
        {/* Sticky Footer */}
        <Footer />
      </body>
    </html>
  );
}