export type Variant = "A" | "B";
const KEY = "reka-ab-hero";

export function getVariant(): Variant {
  if (typeof window === "undefined") return "A";
  
  const qs = new URLSearchParams(window.location.search);
  const forced = qs.get("ab"); 
  if (forced==="a"||forced==="b") { 
    localStorage.setItem(KEY, forced.toUpperCase()); 
    return forced.toUpperCase() as Variant; 
  }
  
  let v = localStorage.getItem(KEY) as Variant | null;
  if (!v) { 
    v = Math.random() < 0.5 ? "A":"B"; 
    localStorage.setItem(KEY, v); 
  }
  return v;
}

export function headlineFor(v: Variant){
  return v==="A"
    ? "Deposit USDT, watch your balance grow."
    : "A simple parking account for your USDT on KAIA.";
}