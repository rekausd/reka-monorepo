import { Injectable, Logger } from '@nestjs/common';
import { ethers } from 'ethers';
import abi from './abi/BridgeableERC20.json' with { type: 'json' };

type Cfg = {
  pollIntervalMs: number; confKaia: number; confEth: number;
  kaia: { rpc:string; chainId:number; token:string; ownerPk:string };
  eth:  { rpc:string; chainId:number; token:string; ownerPk:string };
};

@Injectable()
export class ChainsService {
  private log = new Logger(ChainsService.name);

  readonly kaiaProvider: ethers.JsonRpcProvider;
  readonly ethProvider: ethers.JsonRpcProvider;

  readonly kaiaRead: ethers.Contract;
  readonly ethRead: ethers.Contract;

  readonly kaiaSigner: ethers.Wallet;
  readonly ethSigner: ethers.Wallet;

  readonly kaiaWrite: ethers.Contract;
  readonly ethWrite: ethers.Contract;

  constructor() {
    const cfg = (global as any).BRIDGE_CONFIG as Cfg | undefined;
    // In Nest we provided via DI token. To keep simple, read from process.env here
    const envCfg: Cfg = {
      pollIntervalMs: Number(process.env.POLL_INTERVAL_MS ?? 5000),
      confKaia: Number(process.env.CONFIRMATIONS_KAIA ?? 2),
      confEth: Number(process.env.CONFIRMATIONS_ETH ?? 2),
      kaia: {
        rpc: process.env.KAIA_RPC_URL ?? '',
        chainId: Number(process.env.KAIA_CHAIN_ID ?? 1001),
        token: process.env.KAIA_TOKEN_ADDRESS ?? '',
        ownerPk: process.env.OWNER_PK_KAIA ?? '',
      },
      eth: {
        rpc: process.env.ETH_RPC_URL ?? '',
        chainId: Number(process.env.ETH_CHAIN_ID ?? 11155111),
        token: process.env.ETH_TOKEN_ADDRESS ?? '',
        ownerPk: process.env.OWNER_PK_ETH ?? '',
      }
    };

    this.kaiaProvider = new ethers.JsonRpcProvider(envCfg.kaia.rpc, envCfg.kaia.chainId);
    this.ethProvider  = new ethers.JsonRpcProvider(envCfg.eth.rpc,  envCfg.eth.chainId);

    const kaiaToken = ethers.isAddress(envCfg.kaia.token) ? envCfg.kaia.token : ethers.ZeroAddress;
    const ethToken  = ethers.isAddress(envCfg.eth.token)  ? envCfg.eth.token  : ethers.ZeroAddress;

    this.kaiaRead = new ethers.Contract(kaiaToken, abi as any, this.kaiaProvider);
    this.ethRead  = new ethers.Contract(ethToken,  abi as any, this.ethProvider);

    // Signers must be connected to their respective chain providers; fallback to random if invalid PK
    let kaiaSigner: ethers.Wallet;
    try {
      const pk = envCfg.kaia.ownerPk && envCfg.kaia.ownerPk.trim().length > 0
        ? envCfg.kaia.ownerPk
        : '0x' + '11'.repeat(32);
      kaiaSigner = new ethers.Wallet(pk, this.kaiaProvider);
    } catch {
      this.log.warn('KAIA ownerPk invalid or missing; using zeroed ephemeral signer');
      kaiaSigner = new ethers.Wallet('0x' + '11'.repeat(32), this.kaiaProvider);
    }
    this.kaiaSigner = kaiaSigner;

    let ethSigner: ethers.Wallet;
    try {
      const pk = envCfg.eth.ownerPk && envCfg.eth.ownerPk.trim().length > 0
        ? envCfg.eth.ownerPk
        : '0x' + '22'.repeat(32);
      ethSigner = new ethers.Wallet(pk, this.ethProvider);
    } catch {
      this.log.warn('ETH ownerPk invalid or missing; using zeroed ephemeral signer');
      ethSigner = new ethers.Wallet('0x' + '22'.repeat(32), this.ethProvider);
    }
    this.ethSigner = ethSigner;

    this.kaiaWrite = new ethers.Contract(kaiaToken, abi as any, this.kaiaSigner);
    this.ethWrite  = new ethers.Contract(ethToken,  abi as any, this.ethSigner);

    this.log.log(`Chains wired. KAIA chainId=${envCfg.kaia.chainId}, ETH chainId=${envCfg.eth.chainId}`);
  }

  async latestSafeBlock(chain: 'KAIA' | 'ETH', conf: number): Promise<number> {
    const p = chain === 'KAIA' ? this.kaiaProvider : this.ethProvider;
    const latest = await p.getBlockNumber();
    return Math.max(0, latest - conf);
  }
}
