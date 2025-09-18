import { CCIPBadge } from "@/components/ccip/CCIPPanel";

export function Footer() {
  return (
    <footer className="border-t border-white/10 bg-[#0B0C10]/50">
      <div className="max-w-[480px] mx-auto px-4 py-3">
        <div className="flex items-center justify-between text-[10px] text-gray-500">
          <span>© 2024 ReKaUSD • USDT restaking on KAIA</span>
          <CCIPBadge />
        </div>
      </div>
    </footer>
  );
}