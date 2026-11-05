#!/usr/bin/env node
// Cổng: luật phụ thuộc giữa các lớp Dart (xem lop-luat.mjs). Đọc pubspec + import của app/ và packages/*.
import { readdirSync, readFileSync, existsSync, statSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import { docMucPubspec, docImport, kiemLop } from './lop-luat.mjs';

const goc = join(dirname(fileURLToPath(import.meta.url)), '../..');

function tepDart(thuMuc) {
  if (!existsSync(thuMuc)) return [];
  return readdirSync(thuMuc).flatMap((t) => {
    const p = join(thuMuc, t);
    if (statSync(p).isDirectory()) return t === 'goldens' ? [] : tepDart(p);
    return t.endsWith('.dart') ? [p] : [];
  });
}

const thuMucGoi = ['app', 'app_pro', ...readdirSync(join(goc, 'packages')).map((t) => `packages/${t}`)].filter((t) =>
  existsSync(join(goc, t, 'pubspec.yaml')),
);
const dsGoi = {};
for (const t of thuMucGoi) {
  const yaml = readFileSync(join(goc, t, 'pubspec.yaml'), 'utf8');
  const ten = /^name:\s*(\S+)/m.exec(yaml)[1];
  const tep = ['lib', 'test'].flatMap((con) =>
    tepDart(join(goc, t, con)).map((p) => ({
      duongDan: relative(goc, p),
      lib: con === 'lib',
      imports: docImport(readFileSync(p, 'utf8')),
    })),
  );
  dsGoi[ten] = {
    deps: docMucPubspec(yaml, 'dependencies'),
    devDeps: docMucPubspec(yaml, 'dev_dependencies'),
    tep,
  };
}
const loi = kiemLop(dsGoi);
for (const l of loi) console.error(`✗ ${l}`);
if (loi.length) process.exit(1);
console.log(`lớp phụ thuộc Dart: ${Object.keys(dsGoi).length} gói đúng luật ✓`);
