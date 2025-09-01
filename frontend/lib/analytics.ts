export function track(name: string, props?: Record<string, any>){
  try {
    // Vercel Analytics custom events
    // @ts-ignore
    if (typeof window !== "undefined" && window.va) window.va.track(name, props||{});
  } catch {}
}