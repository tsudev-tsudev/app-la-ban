#!/usr/bin/env node
// Sinh design token từ design/tokens.json (nguồn duy nhất) sang Dart + CSS.
//   node tools/build/tokens.mjs          ghi tệp sinh
//   node tools/build/tokens.mjs --check  đỏ nếu tệp sinh lệch nguồn (dùng trong cổng)
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { homedir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { sinhDart, sinhCss } from './tokens-sinh.mjs';

const goc = join(dirname(fileURLToPath(import.meta.url)), '../..');
const tokens = JSON.parse(readFileSync(join(goc, 'design/tokens.json'), 'utf8'));

// Chạy qua `dart format` để tệp sinh không đổi khi ai đó format cả package.
function dartFormat(ma) {
  const dart = process.env.DART ?? join(homedir(), 'tools/flutter/bin/dart');
  const kq = spawnSync(dart, ['format', '--output=show'], { input: ma, encoding: 'utf8' });
  if (kq.status !== 0) throw new Error(`dart format lỗi (${dart}): ${kq.stderr || kq.error}`);
  return kq.stdout;
}

const dich = {
  'packages/design_system/lib/src/tokens/tokens.g.dart': dartFormat(sinhDart(tokens)),
  'design/gen/tokens.css': sinhCss(tokens),
};

const kiem = process.argv.includes('--check');
const lech = [];
for (const [tep, noiDung] of Object.entries(dich)) {
  const p = join(goc, tep);
  if (kiem) {
    if (!existsSync(p) || readFileSync(p, 'utf8') !== noiDung) lech.push(tep);
  } else {
    mkdirSync(dirname(p), { recursive: true });
    writeFileSync(p, noiDung);
    console.log(`ghi ${tep}`);
  }
}
if (lech.length) {
  console.error(`Tệp token sinh lệch nguồn - chạy: node tools/build/tokens.mjs\n  ${lech.join('\n  ')}`);
  process.exit(1);
}
if (kiem) console.log('token khớp nguồn ✓');
