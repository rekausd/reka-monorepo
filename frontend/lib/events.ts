export const BALANCE_REFRESH_EVENT = 'reka:refresh-balances';

export function triggerBalanceRefresh() {
  if (typeof window === 'undefined') return;
  window.dispatchEvent(new CustomEvent(BALANCE_REFRESH_EVENT));
}

export function addBalanceRefreshListener(fn: () => void) {
  if (typeof window === 'undefined') return () => {};
  window.addEventListener(BALANCE_REFRESH_EVENT, fn);
  return () => window.removeEventListener(BALANCE_REFRESH_EVENT, fn);
}

