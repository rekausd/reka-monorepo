import { Injectable, Logger } from '@nestjs/common';
import { StateRepository } from '../db/state.repository.js';
import { ethers } from 'ethers';

@Injectable()
export class MinterService {
  private log = new Logger(MinterService.name);

  constructor(
    private readonly state: StateRepository,
  ) {}

  async mint(writeContract: ethers.Contract, to: string, amount: bigint, srcEventId: string) {
    if (this.state.isProcessed(srcEventId)) {
      this.log.debug(`Skip already processed ${srcEventId}`);
      return;
    }
    const tx = await writeContract.mint(to, amount);
    const rc = await tx.wait(1);
    this.state.markProcessed(srcEventId);
    this.log.log(`Minted ${amount} to ${to} (tx ${rc?.hash}) for ${srcEventId}`);
  }
}
