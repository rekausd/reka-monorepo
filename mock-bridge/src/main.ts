import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module.js';
import { Logger } from '@nestjs/common';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { logger: ['log','error','warn'] });
  const port = process.env.PORT ? Number(process.env.PORT) : 3000;
  await app.listen(port);
  Logger.log(`ReKa Bridge listening on http://localhost:${port}`);
}
bootstrap();
