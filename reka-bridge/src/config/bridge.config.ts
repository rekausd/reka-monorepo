import { Module, Global } from '@nestjs/common';

@Global()
@Module({
  providers: [
    {
      provide: 'BRIDGE_CONFIG',
      useFactory: () => {
        const cfg = {
          pollIntervalMs: Number(process.env.POLL_INTERVAL_MS ?? 5000),
          confKaia: Number(process.env.CONFIRMATIONS_KAIA ?? 2),
          confEth: Number(process.env.CONFIRMATIONS_ETH ?? 2),
          kaia: {
            rpc: process.env.KAIA_RPC_URL ?? '',
            chainId: Number(process.env.KAIA_CHAIN_ID ?? 1001),
            token: process.env.KAIA_TOKEN_ADDRESS ?? '',
            ownerPk: process.env.OWNER_PK_KAIA ?? ''
          },
          eth: {
            rpc: process.env.ETH_RPC_URL ?? '',
            chainId: Number(process.env.ETH_CHAIN_ID ?? 11155111),
            token: process.env.ETH_TOKEN_ADDRESS ?? '',
            ownerPk: process.env.OWNER_PK_ETH ?? ''
          },
          port: Number(process.env.PORT ?? 3000)
        };
        for (const k of ['rpc','token']) {
          if (!cfg.kaia[k as 'rpc'|'token']) console.warn(`WARN: KAIA ${k} not set`);
          if (!cfg.eth[k as 'rpc'|'token']) console.warn(`WARN: ETH ${k} not set`);
        }
        return cfg;
      }
    }
  ],
  exports: ['BRIDGE_CONFIG']
})
export class BridgeConfigModule {}
