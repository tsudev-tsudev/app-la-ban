import { defineConfig } from 'astro/config';

export default defineConfig({
  site: 'https://compass.tsudev.com',
  compressHTML: true,
  build: { inlineStylesheets: 'never' },
  vite: {
    build: { sourcemap: false, minify: 'terser', terserOptions: { format: { comments: false } } },
  },
});
