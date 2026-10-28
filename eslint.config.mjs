import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  { ignores: ['**/dist/**', '**/.astro/**', '**/.wrangler/**', '**/node_modules/**', 'app/**', 'packages/**', 'native/**'] },
  js.configs.recommended,
  ...tseslint.configs.strict,
  {
    rules: {
      'no-console': 'error',
      'no-debugger': 'error',
      'no-eval': 'error',
      'no-implied-eval': 'error',
    },
  },
  {
    files: ['tools/**/*.mjs', 'eslint.config.mjs', 'web/status/build.mjs'],
    languageOptions: { globals: { process: 'readonly', console: 'readonly', fetch: 'readonly', structuredClone: 'readonly' } },
    rules: { 'no-console': 'off' },
  },
  {
    files: ['web/*/public/**/*.js', 'web/status/src/**/*.js'],
    languageOptions: { globals: { Response: 'readonly', URL: 'readonly', fetch: 'readonly', document: 'readonly' } },
  },
);
