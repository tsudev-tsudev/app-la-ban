#!/usr/bin/env node
// Thử S6 end-to-end trên STAGING THẬT: Access (service token) -> Pages _worker -> service binding -> Worker /admin/v1 ->
// passkey phần mềm (ES256, attestation none) -> phiên __Host-soc -> tổng quan / danh sách -> WebSocket realtime: gây
// một sự kiện bẫy quét (HONEYPOT_HIT) trên compass-api-stg rồi đo thời gian tới khi SOC nhận (ngân sách < 1,5 s).
// Chạy: node tools/thu/soc-e2e.mjs [https://staging.la-ban-admin.pages.dev]
// Cần: ~/.config/la-ban/cau-hinh/access-svc-e2e.json (tools/cloudflare/access.mjs --apply) + dòng admin_users
// 'svc:<client_id>' ở D1 staging. Khoá passkey thử lưu ~/.config/la-ban/cau-hinh/soc-e2e-passkey.json (lần sau đăng nhập).
/* global URL, WebSocket, setTimeout, clearTimeout */
import { createHash, generateKeyPairSync, createPrivateKey, randomBytes, sign } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const GOC = process.argv[2] ?? 'https://staging.la-ban-admin.pages.dev';
const API_STG = 'https://compass-api-stg.tsudev.com';
const THU_MUC = join(homedir(), '.config/la-ban/cau-hinh');
const svc = JSON.parse(readFileSync(join(THU_MUC, 'access-svc-e2e.json'), 'utf8'));
const rpId = new URL(GOC).hostname;
let cookie = '';
let loi = 0;

const kiem = (ten, ok, chiTiet = '') => {
  console.log(`${ok ? 'OK ' : 'LỖI'} ${ten}${chiTiet ? ` - ${chiTiet}` : ''}`);
  if (!ok) loi++;
};

const tieuDe = (them = {}) => ({
  'cf-access-client-id': svc.client_id,
  'cf-access-client-secret': svc.client_secret,
  origin: GOC,
  ...(cookie ? { cookie } : {}),
  ...them,
});

async function goi(duong, body) {
  const r = await fetch(`${GOC}/api${duong}`, {
    method: body === undefined ? 'GET' : 'POST',
    headers: tieuDe(body === undefined ? {} : { 'content-type': 'application/json', 'x-soc': '1' }),
    body: body === undefined ? undefined : JSON.stringify(body),
    redirect: 'manual',
  });
  const sc = r.headers.getSetCookie?.() ?? [];
  for (const c of sc) if (c.startsWith('__Host-soc=')) cookie = c.split(';')[0];
  return { status: r.status, du: await r.json().catch(() => null) };
}

// ---------------------------------------------------------------- authenticator phần mềm
const tepKhoa = join(THU_MUC, 'soc-e2e-passkey.json');
const luu = existsSync(tepKhoa) ? JSON.parse(readFileSync(tepKhoa, 'utf8')) : null;
const khoa = luu?.rpId === rpId ? createPrivateKey({ key: luu.jwk, format: 'jwk' }) : generateKeyPairSync('ec', { namedCurve: 'P-256' }).privateKey;
const credId = luu?.rpId === rpId ? Buffer.from(luu.id, 'base64url') : randomBytes(32);
let dem = luu?.rpId === rpId ? luu.dem : 0;
const ghiKhoa = () => writeFileSync(tepKhoa, JSON.stringify({ rpId, id: credId.toString('base64url'), jwk: khoa.export({ format: 'jwk' }), dem }), { mode: 0o600 });
const sha = (b) => createHash('sha256').update(b).digest();

function cbor(v) {
  const ra = [];
  const dau = (t, n) => (n < 24 ? ra.push((t << 5) | n) : n < 256 ? ra.push((t << 5) | 24, n) : ra.push((t << 5) | 25, n >> 8, n & 0xff));
  const ghi = (x) => {
    if (typeof x === 'number') dau(x >= 0 ? 0 : 1, x >= 0 ? x : -1 - x);
    else if (typeof x === 'string') {
      dau(3, Buffer.byteLength(x));
      ra.push(...Buffer.from(x));
    } else if (Buffer.isBuffer(x)) {
      dau(2, x.length);
      ra.push(...x);
    } else {
      dau(5, x.size);
      for (const [k, val] of x) {
        ghi(k);
        ghi(val);
      }
    }
  };
  ghi(v);
  return Buffer.from(ra);
}

async function dangKy() {
  const bd = await goi('/passkey/dang-ky/bat-dau', {});
  if (bd.status !== 200) return bd;
  const t = bd.du.tuyChon;
  const jwk = khoa.export({ format: 'jwk' });
  const cose = cbor(new Map([[1, 2], [3, -7], [-1, 1], [-2, Buffer.from(jwk.x, 'base64url')], [-3, Buffer.from(jwk.y, 'base64url')]]));
  const ad = Buffer.concat([sha(t.rp.id), Buffer.from([0x45, 0, 0, 0, 0]), Buffer.alloc(16), Buffer.from([0, credId.length]), credId, cose]);
  const cd = Buffer.from(JSON.stringify({ type: 'webauthn.create', challenge: t.challenge, origin: GOC, crossOrigin: false }));
  const att = cbor(new Map([['fmt', 'none'], ['attStmt', new Map()], ['authData', ad]]));
  const kq = await goi('/passkey/dang-ky/xong', { thachThucId: bd.du.thachThucId, clientDataJSON: cd.toString('base64url'), attestationObject: att.toString('base64url'), ten: 'e2e' });
  if (kq.status === 201) ghiKhoa();
  return kq;
}

async function dangNhap() {
  const bd = await goi('/phien/bat-dau', {});
  if (bd.status !== 200) return bd;
  dem++;
  const ad = Buffer.concat([sha(rpId), Buffer.from([0x05, (dem >>> 24) & 0xff, (dem >> 16) & 0xff, (dem >> 8) & 0xff, dem & 0xff])]);
  const cd = Buffer.from(JSON.stringify({ type: 'webauthn.get', challenge: bd.du.tuyChon.challenge, origin: GOC, crossOrigin: false }));
  const ky = sign('sha256', Buffer.concat([ad, sha(cd)]), khoa);
  const kq = await goi('/phien/xong', {
    thachThucId: bd.du.thachThucId,
    id: credId.toString('base64url'),
    clientDataJSON: cd.toString('base64url'),
    authenticatorData: ad.toString('base64url'),
    signature: ky.toString('base64url'),
  });
  ghiKhoa();
  return kq;
}

// ---------------------------------------------------------------- chạy
const trang = await fetch(`${GOC}/`, { redirect: 'manual' });
kiem('không service token -> Access chặn (302 / 403)', [302, 403].includes(trang.status), String(trang.status));
const html = await fetch(`${GOC}/`, { headers: tieuDe() });
kiem('qua Access -> SPA + CSP', html.status === 200 && (html.headers.get('content-security-policy') ?? '').includes("script-src 'self'"), String(html.status));

const toi = await goi('/toi');
kiem('/api/toi (Access JWT + vai trò)', toi.status === 200, JSON.stringify(toi.du));
if (toi.status !== 200) process.exit(1);
kiem('chưa phiên -> /tong-quan 401', (await goi('/tong-quan')).status === 401);
const vao = toi.du.soPasskey === 0 || !luu || luu.rpId !== rpId ? await dangKy() : await dangNhap();
kiem('passkey -> phiên __Host-soc', [200, 201].includes(vao.status) && cookie.startsWith('__Host-soc='), JSON.stringify(vao.du));
const tq = await goi('/tong-quan');
kiem('/tong-quan', tq.status === 200, tq.du ? `thiết bị ${tq.du.thietBi.tong}, D1 ${tq.du.haTang.d1Ms} ms` : '');
const t0 = Date.now();
const ds = await goi('/thiet-bi?limit=100');
kiem('/thiet-bi (< 500 ms server)', ds.status === 200 && ds.du.ms < 500, ds.du ? `${ds.du.ds.length} dòng, D1 ${ds.du.ms} ms, khứ hồi ${Date.now() - t0} ms` : '');

// S7a: trung tâm cảnh báo (lọc + đếm) + passkey của chính mình.
const cb = await goi('/canh-bao?trangThai=tat-ca&limit=20');
kiem('/canh-bao (S7a)', cb.status === 200 && Array.isArray(cb.du?.ds) && typeof cb.du?.dem === 'object', cb.du ? `${cb.du.ds.length} cảnh báo, D1 ${cb.du.ms} ms` : String(cb.status));
const pk = await goi('/passkey');
kiem('/passkey (S7a)', pk.status === 200 && (pk.du?.ds?.length ?? 0) >= 1, pk.du ? `${pk.du.ds.length} passkey` : String(pk.status));
// S7b: rule + mô phỏng 7 ngày, danh sách chặn, cài đặt SOC trong /toi (chỉ đọc - không ghi lên staging).
const quyen = toi.du?.quyen ?? [];
kiem('/toi có caiDat (S7b)', typeof toi.du?.caiDat?.thuyVan?.bat === 'boolean', JSON.stringify(toi.du?.caiDat ?? null));
if (quyen.includes('luat:xem')) {
  const luat = await goi('/luat');
  kiem('/luat (S7b)', luat.status === 200 && (luat.du?.ds?.length ?? 0) >= 5, luat.du ? luat.du.ds.map((x) => `${x.id}:${x.cheDo}`).join(' ') : String(luat.status));
  const r = luat.du?.ds?.find((x) => x.id === 'R-003');
  if (r) {
    const t1 = Date.now();
    const mp = await goi('/luat/mo-phong', { id: r.id, than: { ten: r.ten, dieuKien: r.dieuKien, cuaSo: r.cuaSo, nguong: r.nguong, hanhDong: r.hanhDong } });
    kiem('/luat/mo-phong 7 ngày (S7b)', mp.status === 200 && mp.du?.theoNgay?.length >= 7, mp.du ? `${mp.du.soLanKichHoat} lần / ${mp.du.soSuKien} sự kiện, D1 ${mp.du.ms} ms, khứ hồi ${Date.now() - t1} ms` : String(mp.status));
  }
  const tt = await goi('/thuc-thi?trangThai=tat-ca&limit=20');
  kiem('/thuc-thi (S7b)', tt.status === 200 && Array.isArray(tt.du?.ds), tt.du ? `${tt.du.ds.length} dòng, hiệu lực ${tt.du.dem.hieuLuc ?? 0}, chờ duyệt ${tt.du.dem.choDuyet ?? 0}, Under Attack ${tt.du.underAttack}` : String(tt.status));
  kiem('/yeu-cau-duyet (S7b)', (await goi('/yeu-cau-duyet')).status === 200);
  kiem('/cau-hinh-nguy-co (S7b)', (await goi('/cau-hinh-nguy-co')).status === 200);
}
kiem('/cai-dat-soc đúng quyền (S7b)', (await goi('/cai-dat-soc')).status === (quyen.includes('cai-dat-soc') ? 200 : 403));
kiem('CSRF: thiếu x-soc -> 403', (await fetch(`${GOC}/api/phien/bat-dau`, { method: 'POST', headers: tieuDe({ 'content-type': 'application/json' }), body: '{}' })).status === 403);

const ws = new WebSocket(`${GOC.replace('https', 'wss')}/api/ws`, { headers: tieuDe() });
const moi = await new Promise((xong) => {
  const hen = setTimeout(() => xong(null), 10_000);
  ws.addEventListener('open', async () => {
    const gui = Date.now();
    ws.addEventListener('message', (e) => {
      if (e.data === 'pong') return;
      clearTimeout(hen);
      xong({ tre: Date.now() - gui, tin: JSON.parse(String(e.data)) });
    });
    await fetch(`${API_STG}/wp-login.php`).catch(() => null);
  });
  ws.addEventListener('error', () => xong(null));
});
kiem('WebSocket: sự kiện bẫy quét tới SOC < 1,5 s', !!moi && moi.tre < 1500, moi ? `${moi.tre} ms, ${moi.tin.ds.map((x) => x.type).join(',')}` : 'không nhận được');
ws.close();
kiem('đăng xuất', (await goi('/phien/ket-thuc', {})).status === 200);
console.log(loi === 0 ? '\nTẤT CẢ ĐẠT' : `\n${loi} LỖI`);
process.exit(loi === 0 ? 0 : 1);
