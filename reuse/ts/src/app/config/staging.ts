import type { MyAppConfig, StagingEnv } from '../types';
import { production } from './production';

export const staging = (env: StagingEnv): MyAppConfig => {
  const base = production(env);

  /** One of type-checked alternative to cascade-sheets */
  return {
    ...base,
    title: `App (staging ${env.stagingId})`,
    logger: {
      ...base.logger,
      level: 'warn',
    },
  };
};
