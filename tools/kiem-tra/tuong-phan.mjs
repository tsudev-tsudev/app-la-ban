#!/usr/bin/env node
// Kiểm tương phản WCAG 2.1 AA cho mọi cặp khai báo ở design/tokens.json (mục "contrast"), cả light và dark.
// Chữ thường >= 4.5, thành phần giao diện / chữ lớn >= 3. Đỏ nếu một cặp không đạt.
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { kiemCap } from '../build/mau.mjs';

const goc = join(dirname(fileURLToPath(import.meta.url)), '../..');
const tokens = JSON.parse(readFileSync(join(goc, 'design/tokens.json'), 'utf8'));
const kq = kiemCap(tokens.color, tokens.contrast);
const truot = kq.filter((r) => !r.dat);
if (process.argv.includes('-v') || truot.length) {
  for (const r of kq) {
    console.log(`${r.dat ? '✓' : '✗'} ${r.theme.padEnd(5)} ${r.fg} / ${r.bg}: ${r.ratio.toFixed(2)} (>= ${r.min})`);
  }
}
if (truot.length) {
  console.error(`${truot.length} cặp màu không đạt WCAG AA`);
  process.exit(1);
}
console.log(`tương phản: ${kq.length} cặp đạt AA ✓`);
