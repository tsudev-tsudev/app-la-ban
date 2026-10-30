#!/usr/bin/env node
// Kiểm APK release (SEC-APP APP-02, APP-06): node tools/build/kiem-apk.mjs <tệp.apk>...
// Cần ANDROID_HOME (aapt2 trong build-tools mới nhất) + unzip. Lỗi -> mã thoát 1.
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readdirSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { kiemApk } from './kiem-apk-luat.mjs';

const sdk = process.env.ANDROID_HOME ?? join(process.env.HOME ?? '', 'tools/android-sdk');
const bt = readdirSync(join(sdk, 'build-tools')).sort((a, b) => a.localeCompare(b, undefined, { numeric: true })).at(-1);
const aapt2 = join(sdk, 'build-tools', bt ?? '', 'aapt2');

const apk = process.argv.slice(2);
if (apk.length === 0) {
  console.error('dùng: node tools/build/kiem-apk.mjs <tệp.apk>...');
  process.exit(2);
}
let tong = 0;
for (const f of apk) {
  const xmltree = execFileSync(aapt2, ['dump', 'xmltree', '--file', 'AndroidManifest.xml', f], { encoding: 'utf8' });
  const tep = execFileSync('unzip', ['-Z1', f], { encoding: 'utf8' }).trim().split('\n');
  const tam = mkdtempSync(join(tmpdir(), 'kiem-apk-'));
  try {
    const so = tep.filter((p) => p.endsWith('/libla_ban_kt.so'));
    if (so.length) execFileSync('unzip', ['-q', '-o', f, ...so, '-d', tam]);
    const thuVienKiemTra = so.map((p) => ({ ten: p, noiDung: readFileSync(join(tam, p)).toString('latin1') }));
    const loi = kiemApk({ xmltree, tep, thuVienKiemTra });
    for (const l of loi) console.error(`✗ ${f}: ${l}`);
    if (!loi.length) console.log(`✓ ${f}: không debuggable, chỉ MainActivity exported, có ${so.length} bản libla_ban_kt.so sạch chuỗi`);
    tong += loi.length;
  } finally {
    rmSync(tam, { recursive: true, force: true });
  }
}
process.exit(tong ? 1 : 0);
