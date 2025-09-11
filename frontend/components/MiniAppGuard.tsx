"use client";
import { useMiniApp } from "@/lib/miniapp/init";

export function MiniAppGuard({ children }: { children: React.ReactNode }) {
  const { ready } = useMiniApp();
  
  if (!process.env.NEXT_PUBLIC_MINIAPP_ENABLED || process.env.NEXT_PUBLIC_MINIAPP_ENABLED === "false") {
    return <>{children}</>;
  }
  
  if (!ready) {
    return (
      <div className="min-h-screen flex items-center justify-center bg-[#0B0C10]">
        <div className="text-center">
          <div className="w-12 h-12 border-2 border-indigo-600 border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
          <p className="text-gray-400 text-sm">Initializing Mini App...</p>
        </div>
      </div>
    );
  }
  
  return <>{children}</>;
}