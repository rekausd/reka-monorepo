// Epoch = 10 days, Epoch#0 = today 00:00 UTC (computed per session)
const DAY = 24 * 60 * 60 * 1000;
export const EPOCH_MS = 10 * DAY;

function todayUtcMidnight(): number {
  const now = new Date();
  const utc = Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(), 0, 0, 0, 0);
  return utc; // ms
}

const EPOCH0_START_MS = todayUtcMidnight();

/** Get current epoch info including ms until end */
export function epochNow() {
  const now = Date.now();
  const delta = now - EPOCH0_START_MS;
  const n = delta >= 0 ? Math.floor(delta / EPOCH_MS) : -1; // if before today-00:00 UTC, treat as -1
  const start = EPOCH0_START_MS + (n >= 0 ? n * EPOCH_MS : 0);
  const end = start + EPOCH_MS;
  const remainingMs = Math.max(0, end - now);
  return { 
    epoch: Math.max(0, n), 
    start, 
    end, 
    remainingMs 
  };
}