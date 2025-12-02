/*
  # app.hc (The logic structure is constant)

  Service
    Logger.console
    Database#main-db
      Connect
    APIServer
      Listen
 */

import type {
  ApiServer,
  AppConfig,
  Database,
  Logger,
} from '../HyperCode/types';

export type MyAppConfig = AppConfig & {
  readonly logger: Logger;
  readonly mainDb: Database;
  readonly api: ApiServer;
};

export type ProductionEnv = {
  readonly DATABASE_URL: string;
};

export type StagingEnv = ProductionEnv & {
  readonly stagingId: number;
};
