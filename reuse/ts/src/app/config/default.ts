/*

  # --- Default/Development Settings ---
  Logger:
    level: "debug"

  .console:
    format: "text"

  Database:
    driver: "sqlite"
    file: "dev.sqlite3"

  APIServer > Listen:
    host: "127.0.0.1"
    port: 5000

 */

import type { MyAppConfig } from '../types';

export const default_: MyAppConfig = {
  title: 'App (default)',
  logger: {
    level: 'debug',
    console: {
      format: 'text',
    },
  },
  mainDb: {
    driver: 'sqlite',
    file: 'dev.sqlite3',
  },
  api: {
    listen: {
      host: '127.0.0.1',
      port: 5000,
    },
  },
};
