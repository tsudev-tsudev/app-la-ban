#!/usr/bin/env node
// Ký gói cấu hình mức khiên web (SEC-WEB-SHIELD) bằng Ed25519. Khoá BÍ MẬT ở ~/.config/la-ban/cau-hinh/<kid>.pem (NGOÀI
// repo, quyền 600); chỉ khoá công khai được chép vào web/shield/src/khoa.ts.
//
//   node tools/cau-hinh/ky-cau-hinh.mjs khoa [--kid web-1]               sinh khoá (nếu chưa có), in khoá công khai
//   node tools/cau-hinh/ky-cau-hinh.mjs ky --landing chat --admin chat [--ngay 90] [--kid web-1]   in gói đã ký
//   node tools/cau-hinh/ky-cau-hinh.mjs dua-len --env staging|prod [mức như lệnh ky]   ký + ghi KV CAU_HINH khoá web-khien
import { createPrivateKey, createPublicKey, generateKeyPairSync, sign } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

export const KHOA_KV = 'web-khien';
const MUC = ['tat', 'nhe', 'chat'];
const THU_MUC_KHOA = join(homedir(), '.config/la-ban/cau-hinh');

function b64url(buf) {
  return Buffer.from(buf).toString('base64url');
}

/** Gói đã ký: chữ ký trên đúng các byte của `duLieu` (JSON nội dung) - bên kiểm không cần chuẩn hoá JSON. */
export function kyGoi(khoaBiMat, kid, noiDung) {
  const duLieu = Buffer.from(JSON.stringify(noiDung), 'utf8');
  return { kid, duLieu: b64url(duLieu), chuKy: b64url(sign(null, duLieu, khoaBiMat)) };
}

export function taoNoiDung({ landing, admin, ngay, bayGio }) {
  for (const m of [landing, admin]) if (!MUC.includes(m)) throw new Error(`mức không hợp lệ: ${m}`);
  if (!(ngay >= 1 && ngay <= 365)) throw new Error('--ngay trong 1..365');
  return { v: 1, phatHanh: bayGio, het: bayGio + ngay * 86_400_000, muc: { landing, admin } };
}

function thamSo(argv) {
  const o = { kid: 'web-1', landing: 'chat', admin: 'chat', ngay: 90, env: null };
  for (let i = 0; i < argv.length; i += 2) {
    const k = argv[i]?.replace(/^--/, '');
    if (!k || !(k in o)) throw new Error(`tham số lạ: ${argv[i]}`);
    o[k] = k === 'ngay' ? Number(argv[i + 1]) : argv[i + 1];
  }
  if (!/^[a-z0-9-]{1,32}$/.test(o.kid)) throw new Error('kid sai dạng');
  return o;
}

function napKhoa(kid, taoNeuThieu) {
  const tep = join(THU_MUC_KHOA, `${kid}.pem`);
  if (!existsSync(tep)) {
    if (!taoNeuThieu) throw new Error(`chưa có khoá ${tep} - chạy lệnh khoa trước`);
    mkdirSync(THU_MUC_KHOA, { recursive: true, mode: 0o700 });
    const { privateKey } = generateKeyPairSync('ed25519');
    writeFileSync(tep, privateKey.export({ type: 'pkcs8', format: 'pem' }), { mode: 0o600 });
  }
  return createPrivateKey(readFileSync(tep));
}

function khoaCongKhai(khoaBiMat) {
  return createPublicKey(khoaBiMat).export({ format: 'jwk' }).x;
}

async function main() {
  const [lenh, ...con] = process.argv.slice(2);
  const o = thamSo(con);
  if (lenh === 'khoa') {
    console.log(`${o.kid}: ${khoaCongKhai(napKhoa(o.kid, true))}`);
    return;
  }
  if (lenh !== 'ky' && lenh !== 'dua-len') throw new Error('lệnh: khoa | ky | dua-len');
  const khoa = napKhoa(o.kid, false);
  const goi = kyGoi(khoa, o.kid, taoNoiDung({ landing: o.landing, admin: o.admin, ngay: o.ngay, bayGio: Date.now() }));
  const json = JSON.stringify(goi);
  if (lenh === 'ky') {
    console.log(json);
    return;
  }
  if (o.env !== 'staging' && o.env !== 'prod') throw new Error('--env staging|prod');
  const thuMucApi = join(dirname(fileURLToPath(import.meta.url)), '../../workers/api');
  const thamSoEnv = o.env === 'staging' ? ['--env', 'staging'] : ['--env='];
  execFileSync('npx', ['wrangler', 'kv', 'key', 'put', KHOA_KV, json, '--binding', 'CAU_HINH', '--remote', ...thamSoEnv], {
    cwd: thuMucApi,
    stdio: 'inherit',
  });
  console.log(`Đã ghi ${KHOA_KV} (${o.env}): landing=${o.landing} admin=${o.admin}, hết hạn sau ${o.ngay} ngày.`);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((e) => {
    console.error(String(e.message ?? e));
    process.exit(1);
  });
}
