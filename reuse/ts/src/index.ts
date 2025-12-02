import { config } from './app/config';
import type {
  ProductionEnv,
  StagingEnv,
} from './app/types';
import { HyperCode } from './HyperCode';

const staging: StagingEnv = {
  DATABASE_URL: '...',
  stagingId: 123,
};

const production: ProductionEnv = {
  DATABASE_URL: '...',
};

await HyperCode.run(config.default);
await HyperCode.run(config.production(production));

await HyperCode.compile(config.staging(staging), {
  lang: 'Swift',
});
await HyperCode.compile(config.production(production), {
  lang: 'Rust',
});
