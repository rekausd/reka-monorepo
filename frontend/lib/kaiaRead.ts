import { ethers } from "ethers";
import { ERC20 } from "@/lib/contracts";
import type { AppConfig } from "@/lib/appConfig";

export async function readTotals(cfg: AppConfig){
  const p = new ethers.JsonRpcProvider(cfg.kaiaRpc);
  const rk = new ethers.Contract(cfg.rkUSDT, ERC20, p);
  const dR = await rk.decimals().catch(()=>6);
  const rkSupply = await rk.totalSupply().catch(()=>0n);

  return {
    decR: Number(dR),
    totalStaked: rkSupply,   // 🔁 reuse rkSupply
    rkSupply
  };
}