export type Logger = {
  readonly level: 'debug' | 'info' | 'warn' | 'error';
  readonly console: {
    format: 'text' | 'markdown' | 'json' | 'yaml';
  };
};

export type Database =
  | {
      readonly driver: 'sqlite';
      readonly file: string;
    }
  | {
      readonly driver: 'postgres';
      connectionString: string;
      poolSize: number;
    };

export type ApiServer = {
  readonly listen: {
    readonly host: string;
    readonly port: number;
  };
};

export type AppConfig = {
  readonly title: string;
};
