import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { ChainsService } from './chains.service.js';
import { StateRepository } from '../db/state.repository.js';
import { ethers } from 'ethers';
import abi from './abi/BridgeableERC20.json' with { type: 'json' };
import { makeEventId } from '../common/utils.js';
import { BRIDGE_BURN_EVENT } from '../common/constants.js';

@Injectable()
export class WatcherService implements OnModuleInit {
  private log = new Logger(WatcherService.name);
  private iface = new ethers.Interface(abi as any);

  private runningKaiaToEth = false;
  private runningEthToKaia = false;

  private pollMs = Number(process.env.POLL_INTERVAL_MS ?? 5000);
  private confKaia = Number(process.env.CONFIRMATIONS_KAIA ?? 2);
  private confEth  = Number(process.env.CONFIRMATIONS_ETH ?? 2);

  private kaiaChainId = Number(process.env.KAIA_CHAIN_ID ?? 1001);
  private ethChainId  = Number(process.env.ETH_CHAIN_ID ?? 11155111);

  constructor(
    private readonly chains: ChainsService,
    private readonly state: StateRepository,
  ) {}

  onModuleInit() {
    this.log.log(`Watcher started. Interval=${this.pollMs}ms`);
  }

  @Interval(5000)
  async poll() {
    await Promise.all([
      this.pollDirection('KAIA','ETH'),
      this.pollDirection('ETH','KAIA'),
    ]);
  }

  private async pollDirection(src: 'KAIA'|'ETH', dst: 'KAIA'|'ETH') {
    const flag = src === 'KAIA' ? 'runningKaiaToEth' : 'runningEthToKaia';
    if ((this as any)[flag]) return;
    (this as any)[flag] = true;
    try {
      const srcProv = src === 'KAIA' ? this.chains.kaiaProvider : this.chains.ethProvider;
      const srcRead = src === 'KAIA' ? this.chains.kaiaRead     : this.chains.ethRead;
      const dstWrite = dst === 'KAIA' ? this.chains.kaiaWrite   : this.chains.ethWrite;

      const srcChainId = src === 'KAIA' ? this.kaiaChainId : this.ethChainId;
      const dstChainId = dst === 'KAIA' ? this.kaiaChainId : this.ethChainId;
      const conf = src === 'KAIA' ? this.confKaia : this.confEth;

      const latest = await srcProv.getBlockNumber();
      const safeTo = Math.max(0, latest - conf);

      let cursor = this.state.getCursor(srcChainId);
      if (cursor === null) {
        cursor = safeTo - 5;
        if (cursor < 0) cursor = 0;
      }
      if (safeTo <= cursor) return;

      const ev = this.iface.getEvent(BRIDGE_BURN_EVENT);
      if (!ev) return;
      const topic = ev.topicHash;
      const logs = await srcProv.getLogs({
        address: await srcRead.getAddress(),
        fromBlock: cursor + 1,
        toBlock: safeTo,
        topics: [topic]
      });

      for (const log of logs) {
        const parsed = this.iface.parseLog(log);
        if (!parsed) continue;
        const { from, to, amount, srcChainId, dstChainId, nonce } = parsed.args as any;
        if (Number(dstChainId) !== (dst === 'KAIA' ? this.kaiaChainId : this.ethChainId)) continue;

        const id = makeEventId(srcChainId, log.transactionHash, log.index);
        if (this.state.isProcessed(id)) continue;

        await this.mintSafe(dstWrite, to as string, BigInt(amount.toString()), id);
      }

      this.state.setCursor(srcChainId, safeTo);
    } catch (e:any) {
      this.log.error(`poll ${src}->${dst} error: ${e?.message ?? e}`);
    } finally {
      (this as any)[flag] = false;
    }
  }

  private async mintSafe(dstWrite: any, to: string, amount: bigint, id: string) {
    try {
      const tx = await dstWrite.mint(to, amount);
      const rc = await tx.wait(1);
      this.state.markProcessed(id);
      this.log.log(`Minted on dest to=${to} amt=${amount} (tx ${rc.hash}) from ${id}`);
    } catch (e:any) {
      this.log.error(`mint fail for ${id}: ${e?.message ?? e}`);
    }
  }
}
