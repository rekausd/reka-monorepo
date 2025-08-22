import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ScheduleModule } from '@nestjs/schedule';
import { HealthController } from './http/health.controller.js';
import { BridgeConfigModule } from './config/bridge.config.js';
import { StateRepository } from './db/state.repository.js';
import { ChainsService } from './evm/chains.service.js';
import { MinterService } from './evm/minter.service.js';
import { WatcherService } from './evm/watcher.service.js';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ScheduleModule.forRoot(),
    BridgeConfigModule
  ],
  controllers: [HealthController],
  providers: [StateRepository, ChainsService, MinterService, WatcherService],
})
export class AppModule {}
