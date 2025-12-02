import type { AppConfig } from './types';

export type CompilationTarget = {
  readonly lang: 'Swift' | 'Go' | 'Ts' | 'C++' | 'Rust';
  // TODO: ...
};

// TODO: Generate this code with AI?
export const compile = async <App extends AppConfig>(
  config: App,
  target: CompilationTarget,
) => {
  // TODO: Generate executable code for target language/platform
  console.log(
    'Generate code for',
    config.title,
    'for',
    target.lang,
    '...',
  );
};
