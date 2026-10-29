#!/usr/bin/env node
// Đóng gói /js/khien.js (SH-06): esbuild -> IIFE, rồi terser làm rối (toplevel, 3 lượt nén, đổi tên thuộc tính NỘI BỘ theo
// danh sách). Không eval / new Function, không chuỗi mã hoá cần giải lúc chạy -> tương thích CSP nonce + Trusted Types.
// Thuộc tính đi qua mạng (trang, loai, duongDan, tinHieu, kid, duLieu, chuKy, muc...) KHÔNG nằm trong danh sách đổi tên.
// Dùng: node web/shield/dong-goi.mjs <tệp ra> [<tệp ra> ...]
import { build } from 'esbuild';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { minify } from 'terser';

export const THUOC_TINH_NOI_BO = [
  'phimTat', 'keoAnh', 'chanIn', 'menuChuot', 'saoChep', 'doDevtools',
  'lanBatThuong', 'capNhat', 'ngoaiRong', 'ngoaiCao', 'trongRong', 'trongCao', 'camUng',
  'tieuDe', 'moTa', 'nghi', 'kichThuoc', 'chuKyDoMs',
  'hutNgang', 'thanhAm', 'thanhToiDa', 'lanDoLienTiep', 'diemNghi', 'diemPhimDevtools', 'diemMenuChuot', 'giamMoiMs',
];

const goc = dirname(fileURLToPath(import.meta.url));

export async function dongGoi() {
  const kq = await build({
    entryPoints: [join(goc, 'src/tu-chay.ts')],
    bundle: true,
    write: false,
    format: 'iife',
    target: 'es2022',
    platform: 'browser',
    legalComments: 'none',
    sourcemap: false,
    logLevel: 'warning',
  });
  const ma = kq.outputFiles[0].text;
  const ra = await minify(ma, {
    ecma: 2020,
    toplevel: true,
    compress: { passes: 3, drop_console: true, drop_debugger: true, unsafe_arrows: true },
    mangle: { toplevel: true, properties: { regex: new RegExp(`^(${THUOC_TINH_NOI_BO.join('|')})$`) } },
    format: { comments: false, ascii_only: true },
    sourceMap: false,
  });
  if (!ra.code || /\beval\s*\(|new\s+Function\s*\(/.test(ra.code)) throw new Error('bản khiên rỗng hoặc có eval');
  return ra.code;
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  const dich = process.argv.slice(2);
  if (dich.length === 0) {
    console.error('Cần ít nhất một tệp ra.');
    process.exit(2);
  }
  const ma = await dongGoi();
  for (const tep of dich) {
    mkdirSync(dirname(tep), { recursive: true });
    writeFileSync(tep, ma);
  }
  console.log(`khien.js ${(ma.length / 1024).toFixed(1)} KB -> ${dich.join(', ')}`);
}
