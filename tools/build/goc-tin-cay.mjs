#!/usr/bin/env node
// Sinh bộ CA gốc được GHIM cho kênh app (S3, SEC-NET): app chỉ tin các CA này khi gọi compass-api (neo tin cậy thay cho
// kho CA hệ thống) và Remote Config chọn pin nào đang bật (xoay pin không cần bản mới). dart:io chỉ lộ chứng chỉ lá nên
// ghim ở mức CA gốc - Cloudflare Universal SSL đổi khoá lá mỗi lần gia hạn.
//
//   node tools/build/goc-tin-cay.mjs           sinh packages/network/lib/src/du_lieu/goc_tin_cay.g.dart + tools/cau-hinh/goc-tin-cay.json
//   node tools/build/goc-tin-cay.mjs --check   chỉ so (cổng)
//
// Nguồn PEM: tools/build/goc-tin-cay/*.pem chép từ gói ca-certificates 20260816 (Ubuntu); vân tay dưới đây lấy từ chính
// các tệp đó và pin GTS R4 đã đối chiếu với chuỗi compass-api đang phục vụ (30/10/2026). Đổi CA = thêm tệp + vân tay.
import { createHash, X509Certificate } from 'node:crypto';
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const GOC = join(dirname(fileURLToPath(import.meta.url)), '../..');
const NGUON = join(GOC, 'tools/build/goc-tin-cay');

/** Tên tệp -> SHA-256 chứng chỉ (vân tay công bố bởi CA) để tệp PEM bị tráo thì công cụ dừng. */
export const DANH_SACH = Object.freeze({
  'GTS_Root_R1': 'D9:47:43:2A:BD:E7:B7:FA:90:FC:2E:6B:59:10:1B:12:80:E0:E1:C7:E4:E4:0F:A3:C6:88:7F:FF:57:A7:F4:CF',
  'GTS_Root_R3': '34:D8:A7:3E:E2:08:D9:BC:DB:0D:95:65:20:93:4B:4E:40:E6:94:82:59:6E:8B:6F:73:C8:42:6B:01:0A:6F:48',
  'GTS_Root_R4': '34:9D:FA:40:58:C5:E2:63:12:3B:39:8A:E7:95:57:3C:4E:13:13:C8:3F:E6:8F:93:55:6C:D5:E8:03:1B:3C:7D',
  'ISRG_Root_X1': '96:BC:EC:06:26:49:76:F3:74:60:77:9A:CF:28:C5:A7:CF:E8:A3:C0:AA:E1:1A:8F:FC:EE:05:C0:BD:DF:08:C6',
  'ISRG_Root_X2': '69:72:9B:8E:15:A8:6E:FC:17:7A:57:AF:B7:17:1D:FC:64:AD:D2:8C:2F:CA:8C:F1:50:7E:34:45:3C:CB:14:70',
});

/** SPKI SHA-256 dạng base64 (chuẩn HPKP / OkHttp `sha256/...`). */
export function pinSpki(pem) {
  const der = new X509Certificate(pem).publicKey.export({ type: 'spki', format: 'der' });
  return createHash('sha256').update(der).digest('base64');
}

export function napGoc() {
  return Object.entries(DANH_SACH).map(([ten, van]) => {
    const pem = readFileSync(join(NGUON, `${ten}.pem`), 'utf8').trim();
    const c = new X509Certificate(pem);
    if (c.fingerprint256 !== van) throw new Error(`${ten}: vân tay ${c.fingerprint256} khác ${van}`);
    return { ten, pin: pinSpki(pem), het: new Date(c.validTo).toISOString().slice(0, 10), pem };
  });
}

export function sinhDart(ds) {
  const muc = ds
    .map((g) => `  (\n    ten: '${g.ten}',\n    pin: '${g.pin}',\n    het: '${g.het}',\n    pem: '''\n${g.pem}\n''',\n  ),`)
    .join('\n');
  return `// TỆP SINH - đừng sửa tay: node tools/build/goc-tin-cay.mjs
// CA gốc được ghim cho compass-api (SEC-NET). Chỉ chứng chỉ CÔNG KHAI.

/// CA gốc đóng gói sẵn: tên, pin SPKI SHA-256 (base64), hạn, PEM.
const List<({String ten, String pin, String het, String pem})> gocTinCay = [
${muc}
];
`;
}

function main() {
  const ds = napGoc();
  const dart = sinhDart(ds);
  const json = `${JSON.stringify(ds.map(({ ten, pin, het }) => ({ ten, pin, het })), null, 2)}\n`;
  const tepDart = join(GOC, 'packages/network/lib/src/du_lieu/goc_tin_cay.g.dart');
  const tepJson = join(GOC, 'tools/cau-hinh/goc-tin-cay.json');
  if (process.argv.includes('--check')) {
    const khac = [
      [tepDart, dart],
      [tepJson, json],
    ].filter(([t, nd]) => {
      try {
        return readFileSync(t, 'utf8') !== nd;
      } catch {
        return true;
      }
    });
    // pin-set Android (app/android/app/src/main/res/xml/mang.xml) phải có đủ pin của bộ đóng gói.
    const xml = readFileSync(join(GOC, 'app/android/app/src/main/res/xml/mang.xml'), 'utf8');
    const thieu = ds.filter((g) => !xml.includes(`>${g.pin}</pin>`)).map((g) => g.ten);
    if (thieu.length) khac.push([`mang.xml thiếu pin ${thieu.join(', ')}`, '']);
    if (khac.length) {
      console.error(`goc-tin-cay lệch: ${khac.map(([t]) => t).join(', ')} - chạy node tools/build/goc-tin-cay.mjs`);
      process.exit(1);
    }
    return;
  }
  writeFileSync(tepDart, dart);
  writeFileSync(tepJson, json);
  for (const g of ds) console.log(`${g.ten.padEnd(14)} ${g.pin}  hết ${g.het}`);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) main();
