// S2 end-to-end trên workerd (Miniflare): thách thức -> đăng ký (Play Integrity giả) -> phiên -> làm mới xoay vòng ->
// dùng lại token -> thu hồi chuỗi; Google lỗi -> unverified; token phát lại -> 403 + ATTEST_FAIL.
import type { D1Database } from '@cloudflare/workers-types';
import type { Miniflare } from 'miniflare';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { sha256B64url } from '../src/attest/khoa';
import { chuoiDangKy, chuoiLamMoi, chuoiXacThuc } from '../src/thuan/ma-hoa';
import { taoMf } from './tich-hop/mf';
import { google, googleGia, taoKhoaPhien, taoServiceAccount, taoThietBiGia, tokenGia, type ThietBiGia } from './tich-hop/thiet-bi-gia';

let mf: Miniflare;
let db: D1Database;
const goc = 'https://compass-api.tsudev.com';
const GOI = 'com.tsudev.laban';
let soIp = 0;

const goi = async (duong: string, body?: unknown, them: Record<string, string> = {}) => {
  const res = await mf.dispatchFetch(`${goc}${duong}`, {
    method: body === undefined ? 'GET' : 'POST',
    headers: { 'content-type': 'application/json', 'cf-connecting-ip': `203.0.113.${(soIp++ % 200) + 1}`, ...them },
    ...(body === undefined ? {} : { body: JSON.stringify(body) }),
  });
  const vb = await res.text();
  // eslint-disable-next-line @typescript-eslint/no-explicit-any -- thân phản hồi tuỳ route trong test
  return { status: res.status, du: (vb ? JSON.parse(vb) : null) as Record<string, any> };
};

const phanQuyet = (requestHash: string, o: { tb?: string[]; goi?: string; ts?: number } = {}) => ({
  requestDetails: { requestPackageName: o.goi ?? GOI, requestHash, timestampMillis: String(o.ts ?? Date.now()) },
  appIntegrity: { appRecognitionVerdict: 'UNRECOGNIZED_VERSION', packageName: GOI, certificateSha256Digest: ['zwnnJDvKmrXSnceIu9Mbpx7666t9aVg9mLv8UYSn9r0'], versionCode: '5' },
  deviceIntegrity: { deviceRecognitionVerdict: o.tb ?? ['MEETS_BASIC_INTEGRITY', 'MEETS_DEVICE_INTEGRITY'] },
  accountDetails: { appLicensingVerdict: 'UNEVALUATED' },
});

const thongTin = { heDieuHanh: '13', model: 'SM-M325FV', phienBan: '0.1.0', build: 5, ngonNgu: 'vi' };

async function dangKy(tb: ThietBiGia, id = crypto.randomUUID(), o: { tb?: string[]; token?: 'khong' | 'phat-lai'; goi?: string } = {}) {
  const ch = await goi('/v1/device/challenge', { installationId: id });
  expect(ch.status).toBe(200);
  const thach = ch.du.thachThuc as string;
  const chuoi = chuoiDangKy(thach, id, tb.khoaCongKhai);
  const hash = o.token === 'phat-lai' ? await sha256B64url('yeu-cau-khac') : await sha256B64url(chuoi);
  const integrityToken = o.token === 'khong' ? null : tokenGia(phanQuyet(hash, o.tb ? { tb: o.tb } : {}));
  const r = await goi('/v1/device/register', {
    installationId: id,
    khoaCongKhai: tb.khoaCongKhai,
    thachThuc: thach,
    chuKy: await tb.ky(chuoi),
    nenTang: 'android',
    goi: o.goi ?? GOI,
    integrityToken,
    thongTin,
  });
  return { ...r, id, thach };
}

async function lamMoi(tb: ThietBiGia, refreshToken: string) {
  const ts = Date.now();
  const nonce = crypto.randomUUID().replace(/-/g, '');
  return goi('/v1/session/refresh', { refreshToken, ts, nonce, chuKy: await tb.ky(chuoiLamMoi(refreshToken, ts, nonce)) });
}

const suKien = async (thietBi: string | null, loai: string) => {
  for (let i = 0; i < 20; i++) {
    const r = await db
      .prepare(`SELECT COUNT(*) AS n FROM security_events WHERE type = ? AND ${thietBi ? 'device_id = ?' : 'device_id IS NULL'}`)
      .bind(loai, ...(thietBi ? [thietBi] : []))
      .first<{ n: number }>();
    if ((r?.n ?? 0) > 0) return r?.n ?? 0;
    await new Promise((x) => setTimeout(x, 50));
  }
  return 0;
};

beforeAll(async () => {
  mf = await taoMf(undefined, {
    bindings: { KHOA_PHIEN: await taoKhoaPhien(), PLAY_INTEGRITY_SA_JSON: await taoServiceAccount(), PI_GOI: GOI, PI_CHUNG_CHI: 'cf09e7243bca9ab5d29dc788bbd31ba71efaebab7d69583d98bbfc5184a7f6bd' },
    outboundService: googleGia,
  });
  db = (await mf.getD1Database('DB')) as unknown as D1Database;
}, 60_000);
afterAll(async () => {
  await mf?.dispose();
});
beforeEach(() => {
  google.loi = 0;
});

describe('đăng ký thiết bị', () => {
  it('đủ bước -> 201, mức device, phiên dùng được ở /v1/device/me; device_ips + sessions được ghi', async () => {
    const tb = await taoThietBiGia();
    const r = await dangKy(tb);
    expect(r.status).toBe(201);
    expect(r.du).toMatchObject({ trangThai: 'clean', mucTin: 'device' });
    const me = await goi('/v1/device/me', undefined, { authorization: `Bearer ${r.du.phien.accessToken}` });
    expect(me).toMatchObject({ status: 200, du: { thietBiId: r.du.thietBiId, mucTin: 'device' } });
    const d = await db.prepare('SELECT installation_id_hash, public_key, attest_signals FROM devices WHERE id = ?').bind(r.du.thietBiId).first<Record<string, string>>();
    expect(d?.installation_id_hash).toMatch(/^[0-9a-f]{64}$/);
    expect(d?.installation_id_hash).not.toContain(r.id);
    expect(JSON.parse(d?.attest_signals ?? '{}')).toMatchObject({ app: 'UNRECOGNIZED_VERSION', thiet_bi: 'BASIC,DEVICE' });
    expect((await db.prepare('SELECT COUNT(*) AS n FROM device_ips WHERE device_id = ?').bind(r.du.thietBiId).first<{ n: number }>())?.n).toBe(1);
  });

  it('thách thức chỉ dùng một lần; thách thức của bản cài khác không dùng được', async () => {
    const tb = await taoThietBiGia();
    const r = await dangKy(tb);
    expect(r.status).toBe(201);
    const chuoi = chuoiDangKy(r.thach, r.id, tb.khoaCongKhai);
    const lai = await goi('/v1/device/register', { installationId: r.id, khoaCongKhai: tb.khoaCongKhai, thachThuc: r.thach, chuKy: await tb.ky(chuoi), nenTang: 'android', goi: GOI, integrityToken: null, thongTin });
    expect(lai).toMatchObject({ status: 401, du: { code: 'thach-thuc' } });
    const khac = crypto.randomUUID();
    const ch = await goi('/v1/device/challenge', { installationId: khac });
    const chuoi2 = chuoiDangKy(ch.du.thachThuc, r.id, tb.khoaCongKhai);
    const muon = await goi('/v1/device/register', { installationId: r.id, khoaCongKhai: tb.khoaCongKhai, thachThuc: ch.du.thachThuc, chuKy: await tb.ky(chuoi2), nenTang: 'android', goi: GOI, integrityToken: null, thongTin });
    expect(muon.status).toBe(401);
  });

  it('chữ ký bằng khoá khác -> 401 chu-ky', async () => {
    const tb = await taoThietBiGia();
    const ke = await taoThietBiGia();
    const id = crypto.randomUUID();
    const ch = await goi('/v1/device/challenge', { installationId: id });
    const chuoi = chuoiDangKy(ch.du.thachThuc, id, tb.khoaCongKhai);
    const r = await goi('/v1/device/register', { installationId: id, khoaCongKhai: tb.khoaCongKhai, thachThuc: ch.du.thachThuc, chuKy: await ke.ky(chuoi), nenTang: 'android', goi: GOI, integrityToken: null, thongTin });
    expect(r).toMatchObject({ status: 401, du: { code: 'chu-ky' } });
  });

  it('không có token (máy không Play Services) / Google lỗi -> unverified, vẫn có phiên (ID-05)', async () => {
    expect((await dangKy(await taoThietBiGia(), undefined, { token: 'khong' })).du).toMatchObject({ mucTin: 'unverified' });
    google.loi = 503;
    const r = await dangKy(await taoThietBiGia());
    expect(r).toMatchObject({ status: 201, du: { mucTin: 'unverified' } });
    // Dự án Cloud chưa liên kết -> lỗi cấu hình, không phạt thiết bị.
    google.loi = 4002;
    const chuaLienKet = await dangKy(await taoThietBiGia());
    expect(chuaLienKet).toMatchObject({ status: 201, du: { mucTin: 'unverified' } });
    expect(await suKien(chuaLienKet.du.thietBiId, 'ATTEST_FAIL')).toBe(0);
    // "App is not found" = token rác / giả (máy thật giải mã được dù chưa lên Play) -> failed.
    google.loi = 4001;
    const rac = await dangKy(await taoThietBiGia());
    expect(rac).toMatchObject({ status: 201, du: { mucTin: 'failed' } });
    expect(await suKien(rac.du.thietBiId, 'ATTEST_FAIL')).toBe(1);
  });

  it('thiết bị không đạt toàn vẹn -> failed + ATTEST_FAIL vào Threat Engine', async () => {
    const r = await dangKy(await taoThietBiGia(), undefined, { tb: [] });
    expect(r).toMatchObject({ status: 201, du: { mucTin: 'failed' } });
    expect(await suKien(r.du.thietBiId, 'ATTEST_FAIL')).toBe(1);
  });

  it('token của yêu cầu khác (phát lại) -> 403 attest-sai, không tạo thiết bị', async () => {
    const id = crypto.randomUUID();
    const r = await dangKy(await taoThietBiGia(), id, { token: 'phat-lai' });
    expect(r).toMatchObject({ status: 403, du: { code: 'attest-sai' } });
    expect(await suKien(null, 'ATTEST_FAIL')).toBeGreaterThan(0);
  });

  it('gói không được chấp nhận ở môi trường -> 403', async () => {
    expect((await dangKy(await taoThietBiGia(), undefined, { goi: 'com.tsudev.laban.dev' })).status).toBe(403);
  });

  it('đăng ký lại cùng bản cài (khoá mới) -> cùng thiết bị, phiên cũ bị thu hồi; thiết bị bị cấm -> 403', async () => {
    const id = crypto.randomUUID();
    const dau = await dangKy(await taoThietBiGia(), id);
    const sau = await dangKy(await taoThietBiGia(), id);
    expect(sau.du.thietBiId).toBe(dau.du.thietBiId);
    expect((await goi('/v1/device/me', undefined, { authorization: `Bearer ${dau.du.phien.accessToken}` })).status).toBe(401);
    expect((await goi('/v1/device/me', undefined, { authorization: `Bearer ${sau.du.phien.accessToken}` })).status).toBe(200);
    await db.prepare("UPDATE devices SET status = 'banned' WHERE id = ?").bind(sau.du.thietBiId).run();
    expect((await goi('/v1/device/me', undefined, { authorization: `Bearer ${sau.du.phien.accessToken}` })).status).toBe(403);
    expect((await dangKy(await taoThietBiGia(), id)).du).toMatchObject({ code: 'thiet-bi-bi-cam' });
  });

  it('trường lạ / thiếu token Bearer / JWT giả', async () => {
    expect((await goi('/v1/device/challenge', { installationId: crypto.randomUUID(), them: 1 })).status).toBe(422);
    const me = await mf.dispatchFetch(`${goc}/v1/device/me`);
    expect(me.status).toBe(401);
    expect(me.headers.get('www-authenticate')).toBe('Bearer');
    expect((await goi('/v1/device/me', undefined, { authorization: 'Bearer eyJhbGciOiJub25lIn0.eyJ9.xxxxxxxxxxxxxxxx' })).status).toBe(401);
  });
});

describe('làm mới phiên', () => {
  it('xoay: token mới dùng được, token cũ (ngoài ân hạn) gửi lại -> thu hồi CẢ chuỗi + TOKEN_REUSE', async () => {
    const tb = await taoThietBiGia();
    const r = await dangKy(tb);
    const r1 = r.du.phien.refreshToken as string;
    const m1 = await lamMoi(tb, r1);
    expect(m1).toMatchObject({ status: 200, du: { mucTin: 'device' } });
    const r2 = m1.du.phien.refreshToken as string;
    expect(r2).not.toBe(r1);
    // Trong ân hạn: 409, chưa thu hồi.
    expect(await lamMoi(tb, r1)).toMatchObject({ status: 409, du: { code: 'dang-xoay' } });
    const m2 = await lamMoi(tb, r2);
    expect(m2.status).toBe(200);
    // Đẩy thời điểm xoay của r1 ra ngoài ân hạn rồi dùng lại.
    await db.prepare('UPDATE sessions SET xoay_luc = xoay_luc - 60000 WHERE device_id = ? AND thay_boi IS NOT NULL').bind(r.du.thietBiId).run();
    expect(await lamMoi(tb, r1)).toMatchObject({ status: 401, du: { code: 'phien-thu-hoi' } });
    expect(await lamMoi(tb, m2.du.phien.refreshToken)).toMatchObject({ status: 401, du: { code: 'phien-thu-hoi' } });
    expect((await goi('/v1/device/me', undefined, { authorization: `Bearer ${m2.du.phien.accessToken}` })).status).toBe(401);
    expect(await suKien(r.du.thietBiId, 'TOKEN_REUSE')).toBe(1);
  });

  it('kẻ có refresh token nhưng không có khoá -> 401 chu-ky, KHÔNG thu hồi chuỗi', async () => {
    const tb = await taoThietBiGia();
    const r = await dangKy(tb);
    expect((await lamMoi(await taoThietBiGia(), r.du.phien.refreshToken)).du).toMatchObject({ code: 'chu-ky' });
    expect((await lamMoi(tb, r.du.phien.refreshToken)).status).toBe(200);
  });

  it('nonce phát lại / ts lệch > 60 s -> 401', async () => {
    const tb = await taoThietBiGia();
    const r = await dangKy(tb);
    const rt = r.du.phien.refreshToken as string;
    const ts = Date.now();
    const nonce = 'n'.repeat(32);
    const body = { refreshToken: rt, ts, nonce, chuKy: await tb.ky(chuoiLamMoi(rt, ts, nonce)) };
    expect((await goi('/v1/session/refresh', body)).status).toBe(200);
    expect((await goi('/v1/session/refresh', body)).du).toMatchObject({ code: 'nonce' });
    const cu = Date.now() - 120_000;
    expect((await goi('/v1/session/refresh', { refreshToken: rt, ts: cu, nonce: 'm'.repeat(32), chuKy: await tb.ky(chuoiLamMoi(rt, cu, 'm'.repeat(32))) })).du).toMatchObject({ code: 'lech-gio' });
  });
});

describe('xác minh lại (attest)', () => {
  it('thách thức mới + token mới -> cập nhật mức; cần phiên', async () => {
    const tb = await taoThietBiGia();
    const r = await dangKy(tb, undefined, { token: 'khong' });
    expect(r.du.mucTin).toBe('unverified');
    const ch = await goi('/v1/device/challenge', { installationId: r.id });
    const chuoi = chuoiXacThuc(ch.du.thachThuc, r.du.thietBiId);
    const body = { thachThuc: ch.du.thachThuc, chuKy: await tb.ky(chuoi), goi: GOI, integrityToken: tokenGia(phanQuyet(await sha256B64url(chuoi), { tb: ['MEETS_STRONG_INTEGRITY'] })) };
    expect((await goi('/v1/device/attest', body)).status).toBe(401);
    const a = await goi('/v1/device/attest', body, { authorization: `Bearer ${r.du.phien.accessToken}` });
    expect(a).toMatchObject({ status: 200, du: { mucTin: 'strong' } });
    expect((await goi('/v1/device/me', undefined, { authorization: `Bearer ${r.du.phien.accessToken}` })).du.mucTin).toBe('strong');
  });
});
