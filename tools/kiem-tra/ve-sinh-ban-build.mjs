#!/usr/bin/env node
// SEC-WEB-BUILD B-05: quét thư mục build web, đỏ nếu còn comment, console, debugger, sourcemap hoặc tệp LICENSE tách riêng.
// Dùng: node tools/kiem-tra/ve-sinh-ban-build.mjs <dist> [<dist> ...]  (thư mục không tồn tại thì bỏ qua)
import { existsSync, readdirSync, readFileSync, statSync } from 'node:fs';
import { join, extname } from 'node:path';

const thuMuc = process.argv.slice(2);
if (thuMuc.length === 0) {
  console.error('Cần ít nhất một thư mục build.');
  process.exit(2);
}

function* duyet(goc) {
  for (const ten of readdirSync(goc)) {
    const p = join(goc, ten);
    if (statSync(p).isDirectory()) yield* duyet(p);
    else yield p;
  }
}

// Bỏ chuỗi và regex literal thô trước khi tìm comment JS, kẻo URL "https://" bị tính nhầm.
function boChuoiJs(ma) {
  return ma.replace(/(["'`])(?:\\[\s\S]|(?!\1)[^\\])*\1/g, '""');
}

const luat = {
  '.js': [
    [/\/\*[\s\S]*?\*\//, 'comment /* */'],
    [/(^|[^:\\])\/\/[^\n]*$/m, 'comment //'],
    [/\bconsole\.(log|debug|info|warn|error|trace)\s*\(/, 'console.*'],
    [/\bdebugger\s*;/, 'debugger'],
    [/sourceMappingURL=/, 'tham chiếu sourcemap'],
  ],
  '.css': [
    [/\/\*[\s\S]*?\*\//, 'comment CSS'],
    [/sourceMappingURL=/, 'tham chiếu sourcemap'],
  ],
  '.html': [[/<!--(?!\[if)[\s\S]*?-->/, 'comment HTML']],
};
luat['.mjs'] = luat['.js'];

const loi = [];
let soTep = 0;
for (const goc of thuMuc) {
  if (!existsSync(goc)) continue;
  for (const tep of duyet(goc)) {
    soTep++;
    const ext = extname(tep);
    if (ext === '.map') {
      loi.push(`${tep}: tệp sourcemap`);
      continue;
    }
    if (/LICENSE\.txt$/i.test(tep)) {
      loi.push(`${tep}: tệp LICENSE tách riêng`);
      continue;
    }
    const ds = luat[ext];
    if (!ds) continue;
    let noiDung = readFileSync(tep, 'utf8');
    if (ext === '.js' || ext === '.mjs') noiDung = boChuoiJs(noiDung);
    for (const [mau, ten] of ds) {
      const m = mau.exec(noiDung);
      if (m) loi.push(`${tep}: ${ten} -> ${m[0].slice(0, 80).replace(/\s+/g, ' ')}`);
    }
  }
}

if (loi.length) {
  console.error(`✗ Bản build CHƯA sạch (${loi.length} lỗi):`);
  for (const l of loi) console.error('  ' + l);
  process.exit(1);
}
console.log(`✓ Bản build sạch (${soTep} tệp).`);
