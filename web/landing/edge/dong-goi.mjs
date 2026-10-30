#!/usr/bin/env node
// Sau `astro build`: đóng gói edge/_worker.ts -> dist/_worker.js, src/lib/diem-trang.ts -> dist/js/diem.js,
// src/lib/khieu-nai-trang.ts -> dist/js/khieu-nai.js + sinh
// dist/_routes.json (chỉ trang HTML gọi worker).
import { build } from 'esbuild';
import { readdirSync, statSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { tuyenWorker } from './tuyen.mjs';

const goc = join(dirname(fileURLToPath(import.meta.url)), '..');
const dist = join(goc, 'dist');

await build({
  entryPoints: [join(goc, 'edge/_worker.ts')],
  outfile: join(dist, '_worker.js'),
  bundle: true,
  format: 'esm',
  target: 'es2022',
  platform: 'neutral',
  minify: true,
  legalComments: 'none',
  sourcemap: false,
  logLevel: 'warning',
});

// Trang /w/<token> (A6): giải mã token trên trình duyệt - cùng mã với test (src/lib/diem-chia-se.ts).
await build({
  entryPoints: [join(goc, 'src/lib/diem-trang.ts')],
  outfile: join(dist, 'js/diem.js'),
  bundle: true,
  format: 'iife',
  target: 'es2020',
  platform: 'browser',
  minify: true,
  legalComments: 'none',
  sourcemap: false,
  logLevel: 'warning',
});

// Form khiếu nại (S7c1): Turnstile + gửi Worker - cùng hàm thuần với test (src/lib/khieu-nai.ts).
await build({
  entryPoints: [join(goc, 'src/lib/khieu-nai-trang.ts')],
  outfile: join(dist, 'js/khieu-nai.js'),
  bundle: true,
  format: 'iife',
  target: 'es2020',
  platform: 'browser',
  minify: true,
  legalComments: 'none',
  sourcemap: false,
  logLevel: 'warning',
});

const tepGoc = readdirSync(dist).map((ten) => ({ ten, thuMuc: statSync(join(dist, ten)).isDirectory() }));
writeFileSync(join(dist, '_routes.json'), `${JSON.stringify(tuyenWorker(tepGoc), null, 2)}\n`);
