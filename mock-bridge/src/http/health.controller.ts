import { Controller, Get } from '@nestjs/common';
import { ChainsService } from '../evm/chains.service.js';
import { StateRepository } from '../db/state.repository.js';

@Controller('/healthz')
export class HealthController {
  constructor(
    private readonly chains: ChainsService,
    private readonly state: StateRepository
  ) {}

  @Get()
  async health() {
    const [kaiaBlock, ethBlock] = await Promise.all([
      this.chains.kaiaProvider.getBlockNumber(),
      this.chains.ethProvider.getBlockNumber()
    ]);
    return {
      status: 'ok',
      kaiaBlock,
      ethBlock,
      cursors: {
        kaia: this.state.getCursor(Number(process.env.KAIA_CHAIN_ID ?? 1001)),
        eth: this.state.getCursor(Number(process.env.ETH_CHAIN_ID ?? 11155111))
      }
    };
  }
}
