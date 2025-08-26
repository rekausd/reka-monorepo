export function Footer() {
  return (
    <footer className="mt-auto footer-border bg-[rgba(255,255,255,0.02)]">
      <div className="mx-auto max-w-7xl px-6 py-6">
        <div className="flex flex-col sm:flex-row items-center justify-between gap-4">
          <div className="text-xs text-pendle-gray-400">
            <span>© 2024 ReKaUSD</span>
            <span className="mx-2">•</span>
            <span>USDT restaking on KAIA</span>
          </div>
          <div className="flex items-center gap-6 text-xs">
            <a 
              href="https://github.com/rekausd"
              target="_blank" 
              rel="noopener noreferrer"
              className="text-pendle-gray-400 hover:text-pendle-purple-light transition-colors"
            >
              GitHub
            </a>
            <a 
              href="https://twitter.com/rekausd" 
              target="_blank" 
              rel="noopener noreferrer"
              className="text-pendle-gray-400 hover:text-pendle-purple-light transition-colors"
            >
              Twitter
            </a>
          </div>
        </div>
      </div>
    </footer>
  );
}