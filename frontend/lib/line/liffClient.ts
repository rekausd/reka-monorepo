import liff from '@line/liff';

let liffInitialized = false;
let liffInitPromise: Promise<void> | null = null;

/** Initialize LIFF once on client side. */
export async function initLiff() {
  if (typeof window === 'undefined') return;
  if (liffInitialized) return;
  if (liffInitPromise) return liffInitPromise;

  const liffId = process.env.NEXT_PUBLIC_LIFF_ID!;
  if (!liffId) {
    console.warn('Missing NEXT_PUBLIC_LIFF_ID, skipping LIFF init');
    return;
  }

  liffInitPromise = (async () => {
    try {
      await liff.init({ liffId });
      await liff.ready;
      liffInitialized = true;
      console.log('LIFF initialized with ID:', liffId);
    } catch (err) {
      console.error('LIFF initialization error:', err);
      throw err;
    }
  })();

  return liffInitPromise;
}

export function getLiff() {
  return liff;
}

/** Ensure user is logged into LINE (Mini App webview). */
export async function ensureLiffLogin() {
  const lf = getLiff();
  if (!lf.isLoggedIn()) {
    await lf.login(); // returns to app after login
  }
}