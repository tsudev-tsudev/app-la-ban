#!/usr/bin/env node
// Sinh pseudo-locale en_XA (chỉ dùng trong test giao diện) từ ARB tiếng Anh.
//   node tools/build/arb-gia.mjs          ghi packages/i18n/lib/src/arb/app_en_XA.arb
//   node tools/build/arb-gia.mjs --check  đỏ nếu tệp sinh lệch nguồn (dùng trong cổng)
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { sinhArbGia } from './arb-gia-sinh.mjs';

const goc = join(dirname(fileURLToPath(import.meta.url)), '../..');
const thuMuc = join(goc, 'packages/i18n/lib/src/arb');
const en = JSON.parse(readFileSync(join(thuMuc, 'app_en.arb'), 'utf8'));
const noiDung = JSON.stringify(sinhArbGia(en), null, 2) + '\n';
const tep = join(thuMuc, 'app_en_XA.arb');
if (process.argv.includes('--check')) {
  if (!existsSync(tep) || readFileSync(tep, 'utf8') !== noiDung) {
    console.error(
      'app_en_XA.arb lệch app_en.arb - chạy: node tools/build/arb-gia.mjs (rồi flutter gen-l10n trong packages/i18n)',
    );
    process.exit(1);
  }
  console.log('pseudo-locale en_XA khớp nguồn ✓');
} else {
  writeFileSync(tep, noiDung);
  console.log('ghi packages/i18n/lib/src/arb/app_en_XA.arb');
}
