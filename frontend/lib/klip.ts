export async function connectKlip(): Promise<{ address: string }> {
  // Dynamically import to avoid SSR evaluation issues
  const Klip: any = await import("klip-sdk");
  const res = await Klip.prepare.auth({ bappName: process.env.NEXT_PUBLIC_KLIP_APP_NAME || "ReKaUSD" });
  const { request_key } = res;
  const end = Date.now() + 30000;
  while (Date.now() < end) {
    const r = await Klip.getResult(request_key);
    const addr = (r?.result as any)?.klaytn_address;
    if (addr) return { address: String(addr) };
    await new Promise(r => setTimeout(r, 4000));
  }
  throw new Error("Klip auth timeout");
}
