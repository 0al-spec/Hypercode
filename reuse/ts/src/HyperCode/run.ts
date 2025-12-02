import type { AppConfig } from './types';

// TODO: Generate this code with AI?
export const run = async <App extends AppConfig>(
  config: App,
) => {
  // TODO: Run app in the env as interpreter
  console.log('Run', config.title, '...');
};
