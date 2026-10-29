#!/usr/bin/env node
// Ký gói cấu hình mức khiên web (SEC-WEB-SHIELD) bằng Ed25519. Khoá BÍ MẬT ở ~/.config/la-ban/cau-hinh/<kid>.pem (NGOÀI
// repo, quyền 600); chỉ khoá công khai được chép vào web/shield/src/khoa.ts.
//
//   node tools/cau-hinh/ky-cau-hinh.mjs khoa [--kid web-1]               sinh khoá (nếu chưa có), in khoá công khai
//   node tools/cau-hinh/ky-cau-hinh.mjs ky --landing chat --admin chat [--ngay 90] [--kid web-1]   in gói đã ký
//   node tools/cau-hinh/ky-cau-hinh.mjs dua-len --env staging|prod [mức như lệnh ky]   ký + ghi KV CAU_HINH khoá web-khien
//
// Remote Config của APP (S3, SEC-NET) - khoá riêng kid app-1, khoá công khai chép vào packages/network/lib/src/khoa_cau_hinh.dart:
//   node tools/cau-hinh/ky-cau-hinh.mjs khoa --kid app-1
//   node tools/cau-hinh/ky-cau-hinh.mjs ky-app [--toi-thieu 1] [--khuyen-nghi 1] [--tat ban-do,ar] [--pin p1,p2|mac-dinh]
//        [--goc-them a.pem,b.pem] [--ngay 90] [--kid app-1]                              in gói đã ký
//   node tools/cau-hinh/ky-cau-hinh.mjs dua-len-app --env staging|prod [như ky-app]      ký + ghi KV khoá app-cau-hinh
// Pin = SPKI SHA-256 base64 của CA gốc; mặc định = mọi CA trong tools/cau-hinh/goc-tin-cay.json. Pin không có trong bộ
// đóng gói của app thì PHẢI kèm --goc-them (PEM của CA đó) - app chỉ tin CA nó có PEM.
import { createHash, createPrivateKey, createPublicKey, generateKeyPairSync, sign, X509Certificate } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

export const KHOA_KV = 'web-khien';
export const KHOA_KV_APP = 'app-cau-hinh';
/** Tên cờ tắt từ xa app hiểu (khớp `CoTinhNang` ở packages/storage - app đổi `banDo` <-> `ban-do`). */
export const TINH_NANG = ['ban-do', 'ar', 'chia-se', 'dong-bo', 'quang-cao'];
const MAU_PIN = /^[A-Za-z0-9+/]{43}=$/;
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

/** SPKI SHA-256 base64 của chứng chỉ PEM. */
export function pinPem(pem) {
  return createHash('sha256').update(new X509Certificate(pem).publicKey.export({ type: 'spki', format: 'der' })).digest('base64');
}

/**
 * Nội dung Remote Config app: hạn, cập nhật bắt buộc / khuyến nghị (mã build), cờ tắt, pin CA (>= 2 - SEC-NET) + PEM CA
 * mới. Mọi pin phải thuộc bộ đóng gói [pinDongGoi] hoặc có PEM trong [gocThem].
 */
export function taoNoiDungApp({ toiThieu = 1, khuyenNghi = 1, tat = [], pin, gocThem = [], pinDongGoi, ngay, bayGio }) {
  if (!Number.isInteger(toiThieu) || !Number.isInteger(khuyenNghi) || toiThieu < 1 || khuyenNghi < toiThieu) throw new Error('cần 1 <= --toi-thieu <= --khuyen-nghi (mã build)');
  if (!(ngay >= 1 && ngay <= 365)) throw new Error('--ngay trong 1..365');
  for (const t of tat) if (!TINH_NANG.includes(t)) throw new Error(`cờ lạ: ${t} (có: ${TINH_NANG.join(', ')})`);
  const pinThem = gocThem.map(pinPem);
  const dsPin = [...new Set(pin ?? pinDongGoi)];
  if (dsPin.length < 2) throw new Error('cần >= 2 pin (1 đang dùng + 1 dự phòng)');
  for (const p of dsPin) {
    if (!MAU_PIN.test(p)) throw new Error(`pin sai dạng: ${p}`);
    if (!pinDongGoi.includes(p) && !pinThem.includes(p)) throw new Error(`pin ${p} không có trong app - thêm --goc-them <pem>`);
  }
  for (const p of pinThem) if (!dsPin.includes(p)) throw new Error(`PEM thêm có pin ${p} không nằm trong --pin`);
  return {
    v: 1,
    phatHanh: bayGio,
    het: bayGio + ngay * 86_400_000,
    capNhat: { toiThieu, khuyenNghi },
    tat: [...new Set(tat)].sort(),
    pin: dsPin,
    gocThem: gocThem.map((g) => g.trim()),
  };
}

function thamSoApp(argv) {
  const o = { kid: 'app-1', 'toi-thieu': '1', 'khuyen-nghi': '1', tat: '', pin: 'mac-dinh', 'goc-them': '', ngay: '90', env: null };
  for (let i = 0; i < argv.length; i += 2) {
    const k = argv[i]?.replace(/^--/, '');
    if (!k || !(k in o)) throw new Error(`tham số lạ: ${argv[i]}`);
    o[k] = argv[i + 1] ?? '';
  }
  if (!/^[a-z0-9-]{1,32}$/.test(o.kid)) throw new Error('kid sai dạng');
  const ds = (s) => s.split(',').map((x) => x.trim()).filter(Boolean);
  const thuMuc = dirname(fileURLToPath(import.meta.url));
  const pinDongGoi = JSON.parse(readFileSync(join(thuMuc, 'goc-tin-cay.json'), 'utf8')).map((g) => g.pin);
  return {
    kid: o.kid,
    env: o.env,
    noiDung: (bayGio) =>
      taoNoiDungApp({
        toiThieu: Number(o['toi-thieu']),
        khuyenNghi: Number(o['khuyen-nghi']),
        tat: ds(o.tat),
        pin: o.pin === 'mac-dinh' ? undefined : ds(o.pin),
        gocThem: ds(o['goc-them']).map((t) => readFileSync(t, 'utf8')),
        pinDongGoi,
        ngay: Number(o.ngay),
        bayGio,
      }),
  };
}

function ghiKv(env, khoaKv, json) {
  if (env !== 'staging' && env !== 'prod') throw new Error('--env staging|prod');
  const thuMucApi = join(dirname(fileURLToPath(import.meta.url)), '../../workers/api');
  const thamSoEnv = env === 'staging' ? ['--env', 'staging'] : ['--env='];
  execFileSync('npx', ['wrangler', 'kv', 'key', 'put', khoaKv, json, '--binding', 'CAU_HINH', '--remote', ...thamSoEnv], { cwd: thuMucApi, stdio: 'inherit' });
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
  if (lenh === 'ky-app' || lenh === 'dua-len-app') {
    const a = thamSoApp(con);
    const nd = a.noiDung(Date.now());
    const json = JSON.stringify(kyGoi(napKhoa(a.kid, false), a.kid, nd));
    if (lenh === 'ky-app') {
      console.log(json);
      return;
    }
    ghiKv(a.env, KHOA_KV_APP, json);
    console.log(`Đã ghi ${KHOA_KV_APP} (${a.env}): build tối thiểu ${nd.capNhat.toiThieu}, khuyến nghị ${nd.capNhat.khuyenNghi}, tắt [${nd.tat}], ${nd.pin.length} pin, hết hạn ${new Date(nd.het).toISOString().slice(0, 10)}.`);
    return;
  }
  const o = thamSo(con);
  if (lenh === 'khoa') {
    console.log(`${o.kid}: ${khoaCongKhai(napKhoa(o.kid, true))}`);
    return;
  }
  if (lenh !== 'ky' && lenh !== 'dua-len') throw new Error('lệnh: khoa | ky | dua-len | ky-app | dua-len-app');
  const khoa = napKhoa(o.kid, false);
  const goi = kyGoi(khoa, o.kid, taoNoiDung({ landing: o.landing, admin: o.admin, ngay: o.ngay, bayGio: Date.now() }));
  const json = JSON.stringify(goi);
  if (lenh === 'ky') {
    console.log(json);
    return;
  }
  ghiKv(o.env, KHOA_KV, json);
  console.log(`Đã ghi ${KHOA_KV} (${o.env}): landing=${o.landing} admin=${o.admin}, hết hạn sau ${o.ngay} ngày.`);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((e) => {
    console.error(String(e.message ?? e));
    process.exit(1);
  });
}
