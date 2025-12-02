/*

  # --- Production Environment Overrides ---
  @env[production]:
    Logger:
      level: "info"

    .console:
      format: "json" # Switch to structured logging for production

    '#main-db':
      driver: "postgres"
      connection_string: "${DATABASE_URL}" # Use environment variable
      pool_size: 50

    APIServer > Listen:
      host: "0.0.0.0"
      port: 8080

 */

import type { MyAppConfig, ProductionEnv } from '../types';

export const production = ({
  DATABASE_URL,
}: ProductionEnv): MyAppConfig => ({
  title: 'App (production)',
  logger: {
    level: 'info',
    console: {
      format: 'json',
    },
  },
  mainDb: {
    driver: 'postgres',
    connectionString: `${DATABASE_URL}`,
    poolSize: 50,
  },
  api: {
    listen: {
      host: '0.0.0.0',
      port: 8080,
    },
  },
});
