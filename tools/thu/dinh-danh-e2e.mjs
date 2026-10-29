// Thử S2 end-to-end trên môi trường THẬT (mặc định staging): thách thức -> đăng ký bằng khoá P-256 phần mềm (không token
// Play -> mức 'unverified') -> /v1/device/me -> làm mới -> dùng lại token cũ ngoài ân hạn KHÔNG thử (cần chờ 30 s).
// Chạy: node tools/thu/dinh-danh-e2e.mjs [https://compass-api-stg.tsudev.com]
// Thiết bị thử có model 'node' + os_version 'e2e' -> dọn sau khi thử (xoá sessions / device_ips / security_events /
// device_links của chúng trước, rồi devices) để SOC không thấy dữ liệu rác.
import { createHash, generateKeyPairSync, randomUUID, randomBytes, sign } from 'node:crypto';

const goc = process.argv[2] ?? 'https://compass-api-stg.tsudev.com';
const goi = goc.includes('-stg') ? 'com.tsudev.laban.stg' : 'com.tsudev.laban';
const { privateKey, publicKey } = generateKeyPairSync('ec', { namedCurve: 'P-256' });
const spki = publicKey.export({ type: 'spki', format: 'der' }).toString('base64url');
const ky = (s) => sign('sha256', Buffer.from(s), privateKey).toString('base64url');
const post = async (duong, body, bearer) => {
  const r = await fetch(goc + duong, {
    method: body ? 'POST' : 'GET',
    headers: { 'content-type': 'application/json', ...(bearer ? { authorization: `Bearer ${bearer}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { status: r.status, du: await r.json().catch(() => null) };
};
const buoc = (ten, r, mong) => {
  const dat = r.status === mong;
  console.log(`${dat ? 'DAT ' : 'TRUOT'} ${ten}: ${r.status}${r.du?.code ? ` ${r.du.code}` : ''}`);
  if (!dat) process.exitCode = 1;
  return dat;
};

const id = randomUUID();
const ch = await post('/v1/device/challenge', { installationId: id });
if (!buoc('challenge', ch, 200)) process.exit();
const chuoi = `la-ban/v1/dang-ky\n${ch.du.thachThuc}\n${id}\n${spki}`;
const dk = await post('/v1/device/register', {
  installationId: id, khoaCongKhai: spki, thachThuc: ch.du.thachThuc, chuKy: ky(chuoi), nenTang: 'android', goi,
  integrityToken: null, thongTin: { heDieuHanh: 'e2e', model: 'node', phienBan: '0.0.0', build: 1, ngonNgu: 'vi' },
});
if (!buoc('register', dk, 201)) process.exit();
console.log(`     thiết bị ${dk.du.thietBiId} mức ${dk.du.mucTin} trạng thái ${dk.du.trangThai}`);
buoc('me', await post('/v1/device/me', null, dk.du.phien.accessToken), 200);
const lamMoi = async (rt) => {
  const ts = Date.now();
  const nonce = randomBytes(24).toString('base64url');
  return post('/v1/session/refresh', { refreshToken: rt, ts, nonce, chuKy: ky(`la-ban/v1/lam-moi\n${rt}\n${ts}\n${nonce}`) });
};
const lm = await lamMoi(dk.du.phien.refreshToken);
buoc('refresh', lm, 200);
buoc('refresh token cũ trong ân hạn -> 409', await lamMoi(dk.du.phien.refreshToken), 409);
buoc('access token cũ sau xoay -> 401', await post('/v1/device/me', null, dk.du.phien.accessToken), 401);
buoc('access token mới', await post('/v1/device/me', null, lm.du?.phien?.accessToken), 200);
console.log('requestHash mẫu:', createHash('sha256').update(chuoi).digest('base64url'));
