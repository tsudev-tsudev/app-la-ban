#!/usr/bin/env node
// Sinh mã Dart vẽ bộ icon 24dp (QUYET_DINH Q30) từ design/icons/*.svg.
//   node tools/build/icon-dart.mjs          ghi packages/design_system/lib/src/icons/lb_icons.g.dart
//   node tools/build/icon-dart.mjs --check  đỏ nếu tệp sinh lệch nguồn (dùng trong cổng)
import { readdirSync, readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { homedir } from 'node:os';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { sinhIconDart } from './icon-dart-sinh.mjs';

const goc = join(dirname(fileURLToPath(import.meta.url)), '../..');
const thuMuc = join(goc, 'design/icons');
const dsIcon = Object.fromEntries(
  readdirSync(thuMuc)
    .filter((t) => t.endsWith('.svg'))
    .map((t) => [t.replace(/\.svg$/, ''), readFileSync(join(thuMuc, t), 'utf8')]),
);

const dart = process.env.DART ?? join(homedir(), 'tools/flutter/bin/dart');
const kq = spawnSync(dart, ['format', '--output=show'], { input: sinhIconDart(dsIcon), encoding: 'utf8' });
if (kq.status !== 0) throw new Error(`dart format lỗi (${dart}): ${kq.stderr || kq.error}`);

const tep = 'packages/design_system/lib/src/icons/lb_icons.g.dart';
const p = join(goc, tep);
if (process.argv.includes('--check')) {
  if (!existsSync(p) || readFileSync(p, 'utf8') !== kq.stdout) {
    console.error(`${tep} lệch design/icons - chạy: node tools/build/icon-dart.mjs`);
    process.exit(1);
  }
  console.log(`icon Dart khớp nguồn (${Object.keys(dsIcon).length} icon) ✓`);
} else {
  writeFileSync(p, kq.stdout);
  console.log(`ghi ${tep}`);
}
