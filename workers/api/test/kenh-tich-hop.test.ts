// S3 trên workerd (Miniflare): chữ ký request (sai chữ ký / phát lại / hết hạn / sửa thân / khoá khác bị từ chối),
// /v1/config (gói ký nguyên văn từ KV), /v1/status (REF + bản mới), /v1/events (Threat Engine, chống trùng).
import type { D1Database, KVNamespace, R2Bucket } from '@cloudflare/workers-types';
import type { Miniflare } from 'miniflare';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { chuoiDangKy } from '../src/thuan/ma-hoa';
import { taoMf } from './tich-hop/mf';
import { taoKhoaPhien, taoThietBiGia, tieuDeKy, type ThietBiGia } from './tich-hop/thiet-bi-gia';

let mf: Miniflare;
let db: D1Database;
const goc = 'https://compass-api.tsudev.com';
const GOI = 'com.tsudev.laban';
let soIp = 0;

const goi = async (duong: string, o: { body?: string; tieuDe?: Record<string, string>; phuongThuc?: string } = {}) => {
  const res = await mf.dispatchFetch(`${goc}${duong}`, {
    method: o.phuongThuc ?? (o.body === undefined ? 'GET' : 'POST'),
    headers: { 'content-type': 'application/json', 'cf-connecting-ip': `198.51.100.${(soIp++ % 200) + 1}`, ...o.tieuDe },
    ...(o.body === undefined ? {} : { body: o.body }),
  });
  const vb = await res.text();
  // eslint-disable-next-line @typescript-eslint/no-explicit-any -- thân phản hồi tuỳ route trong test
  return { status: res.status, headers: res.headers, du: (vb ? JSON.parse(vb) : null) as Record<string, any> };
};

type ThietBiThu = { tb: ThietBiGia; id: string; token: string };

async function dangKy(): Promise<ThietBiThu> {
  const tb = await taoThietBiGia();
  const installationId = crypto.randomUUID();
  const ch = await goi('/v1/device/challenge', { body: JSON.stringify({ installationId }) });
  const thach = ch.du.thachThuc as string;
  const r = await goi('/v1/device/register', {
    body: JSON.stringify({
      installationId,
      khoaCongKhai: tb.khoaCongKhai,
      thachThuc: thach,
      chuKy: await tb.ky(chuoiDangKy(thach, installationId, tb.khoaCongKhai)),
      nenTang: 'android',
      goi: GOI,
      integrityToken: null,
      thongTin: { heDieuHanh: '13', model: 'SM-M325FV', phienBan: '0.1.0', build: 6, ngonNgu: 'vi' },
    }),
  });
  expect(r.status).toBe(201);
  return { tb, id: r.du.thietBiId, token: r.du.phien.accessToken };
}

const goiKy = async (t: ThietBiThu, duong: string, body?: string, them: Partial<Parameters<typeof tieuDeKy>[2]> = {}) =>
  goi(duong, {
    ...(body === undefined ? {} : { body }),
    tieuDe: await tieuDeKy(t.tb, t.token, { phuongThuc: body === undefined ? 'GET' : 'POST', duong, ...(body === undefined ? {} : { than: body }), ...them }),
  });

const suKien = (id: string, loai: string) => ({
  event_id: crypto.randomUUID(),
  ts: new Date().toISOString(),
  type: loai,
  severity: 'medium',
  signals: { hook: true },
  app: { version: '0.1.0', build: 6, install_source: null },
  env: { os: 'android', os_ver: '13', model: 'SM-M325FV', emulator: false, root: 'no' },
  ...(id ? { event_id: id } : {}),
});

const demSuKien = async (thietBi: string, loai: string) => {
  for (let i = 0; i < 20; i++) {
    const r = await db.prepare('SELECT COUNT(*) AS n FROM security_events WHERE type = ? AND device_id = ?').bind(loai, thietBi).first<{ n: number }>();
    if ((r?.n ?? 0) > 0) return r?.n ?? 0;
    await new Promise((x) => setTimeout(x, 50));
  }
  return 0;
};

beforeAll(async () => {
  mf = await taoMf(undefined, { bindings: { KHOA_PHIEN: await taoKhoaPhien(), PI_GOI: GOI } });
  db = (await mf.getD1Database('DB')) as unknown as D1Database;
}, 60_000);
afterAll(async () => {
  await mf?.dispose();
});

describe('chữ ký request (SEC-NET)', () => {
  it('ký đúng -> 200; thiếu header ký -> 401 can-chu-ky', async () => {
    const t = await dangKy();
    expect((await goiKy(t, '/v1/device/me')).status).toBe(200);
    expect((await goiKy(t, '/v1/device/me', undefined, { thietBi: t.id })).status).toBe(200);
    expect((await goi('/v1/device/me', { tieuDe: { authorization: `Bearer ${t.token}` } })).du).toMatchObject({ status: 401, code: 'can-chu-ky' });
  });

  it('phát lại cùng nonce -> 401 nonce', async () => {
    const t = await dangKy();
    const tieuDe = await tieuDeKy(t.tb, t.token, { phuongThuc: 'GET', duong: '/v1/device/me' });
    expect((await goi('/v1/device/me', { tieuDe })).status).toBe(200);
    expect((await goi('/v1/device/me', { tieuDe })).du).toMatchObject({ status: 401, code: 'nonce' });
  });

  it('R3c: luật theo thiết bị đếm chung batch nonce - vượt 60 / phút ở /v1/device/me -> 429 + Retry-After; thiết bị khác không bị', async () => {
    const t = await dangKy();
    const ma: number[] = [];
    for (let i = 0; i < 60; i++) ma.push((await goiKy(t, '/v1/device/me')).status);
    expect(ma.every((m) => m === 200)).toBe(true);
    const vuot = await goiKy(t, '/v1/device/me');
    expect(vuot.du).toMatchObject({ status: 429, code: 'qua-nhieu-yeu-cau' });
    expect(Number(vuot.headers.get('retry-after'))).toBeGreaterThan(0);
    expect((await goiKy(await dangKy(), '/v1/device/me')).status).toBe(200);
  }, 30_000);

  it('ts lệch > 60 s -> 401 lech-gio kèm x-server-time', async () => {
    const t = await dangKy();
    const r = await goiKy(t, '/v1/device/me', undefined, { ts: Date.now() - 61_000 });
    expect(r.du).toMatchObject({ status: 401, code: 'lech-gio' });
    expect(Math.abs(Number(r.headers.get('x-server-time')) - Date.now())).toBeLessThan(5_000);
    expect((await goiKy(t, '/v1/device/me', undefined, { ts: Date.now() + 61_000 })).du.code).toBe('lech-gio');
  });

  it('khoá khác (cầm JWT không có khoá) -> 401 chu-ky + SIGNATURE_MISMATCH; nonce KHÔNG bị đốt', async () => {
    const t = await dangKy();
    const nonce = 'q'.repeat(22);
    const gia = await tieuDeKy(await taoThietBiGia(), t.token, { phuongThuc: 'GET', duong: '/v1/device/me', nonce });
    expect((await goi('/v1/device/me', { tieuDe: gia })).du).toMatchObject({ status: 401, code: 'chu-ky' });
    expect(await demSuKien(t.id, 'SIGNATURE_MISMATCH')).toBe(1);
    expect((await goiKy(t, '/v1/device/me', undefined, { nonce })).status).toBe(200);
  });

  it('sửa thân / đường dẫn / phương thức sau khi ký -> 401 chu-ky', async () => {
    const t = await dangKy();
    const lo = JSON.stringify({ events: [suKien('', 'ROOT_DETECTED')] });
    const tieuDe = await tieuDeKy(t.tb, t.token, { phuongThuc: 'POST', duong: '/v1/events', than: lo });
    const sua = lo.replace('"medium"', '"low"');
    expect((await goi('/v1/events', { body: sua, tieuDe })).du.code).toBe('chu-ky');
    const tieuDeMe = await tieuDeKy(t.tb, t.token, { phuongThuc: 'GET', duong: '/v1/device/me' });
    expect((await goi('/v1/status', { tieuDe: tieuDeMe })).du.code).toBe('chu-ky');
    expect((await goi('/v1/device/me?x=1', { tieuDe: await tieuDeKy(t.tb, t.token, { phuongThuc: 'GET', duong: '/v1/device/me?x=2' }) })).du.code).toBe('chu-ky');
    expect((await goi('/v1/device/me?b=2&a=1', { tieuDe: await tieuDeKy(t.tb, t.token, { phuongThuc: 'GET', duong: '/v1/device/me?a=1&b=2' }) })).status).toBe(200);
  });

  it('X-Device-Id khác thiết bị của phiên -> 401; JWT cũ sau khi khoá đổi -> 401', async () => {
    const t = await dangKy();
    expect((await goiKy(t, '/v1/device/me', undefined, { thietBi: '01JC0000000000000000000000' })).du.code).toBe('thiet-bi-khac');
    // Khoá thiết bị đổi trong D1 (đăng ký lại) mà phiên cũ chưa kịp thu hồi: jkt không còn khớp.
    await db.prepare('UPDATE devices SET public_key = ? WHERE id = ?').bind((await taoThietBiGia()).khoaCongKhai, t.id).run();
    expect((await goiKy(t, '/v1/device/me')).du.code).toBe('phien-thu-hoi');
  });
});

describe('/v1/config', () => {
  it('chưa có gói -> 404; gói đúng hình dạng -> trả nguyên văn; sai hình dạng -> 404', async () => {
    expect((await goi('/v1/config')).status).toBe(404);
    const kv = (await mf.getKVNamespace('CAU_HINH')) as unknown as KVNamespace;
    const goiKyAp = { kid: 'app-1', duLieu: 'eyJ2IjoxfQ', chuKy: 'A'.repeat(86) };
    await kv.put('app-cau-hinh', JSON.stringify(goiKyAp));
    const r = await goi('/v1/config');
    expect(r).toMatchObject({ status: 200, du: goiKyAp });
    expect(r.headers.get('cache-control')).toBe('public, max-age=60');
    await kv.put('app-cau-hinh', JSON.stringify({ ...goiKyAp, them: 1 }));
    expect((await goi('/v1/config')).status).toBe(404);
  });
});

describe('/v1/status', () => {
  it('thiết bị thường: không REF, có bản mới từ latest.json; bị cấm: vẫn đọc được + REF, route khác 403', async () => {
    const cdn = (await mf.getR2Bucket('CDN')) as unknown as R2Bucket;
    await cdn.put('android/latest.json', JSON.stringify({ phienBan: '0.1.0-beta.6', maPhienBan: 6, tep: [] }));
    const t = await dangKy();
    expect(await goiKy(t, '/v1/status')).toMatchObject({
      status: 200,
      du: { trangThai: 'clean', mucTin: 'unverified', ref: null, banMoi: { phienBan: '0.1.0-beta.6', maPhienBan: 6 } },
    });
    await db.prepare("UPDATE devices SET status = 'banned' WHERE id = ?").bind(t.id).run();
    const s = await goiKy(t, '/v1/status');
    expect(s).toMatchObject({ status: 200, du: { trangThai: 'banned' } });
    expect(s.du.ref).toBe(`REF-${t.id.slice(-10, -5)}-${t.id.slice(-5)}`);
    expect((await goiKy(t, '/v1/device/me')).status).toBe(403);
  });
});

describe('/v1/events', () => {
  it('lô ký đúng -> 202 + ghi security_events; gửi lại cùng event_id -> trùng', async () => {
    const t = await dangKy();
    const id = crypto.randomUUID();
    const lo = JSON.stringify({ events: [suKien(id, 'ROOT_DETECTED'), suKien('', 'HOOK_DETECTED')] });
    expect(await goiKy(t, '/v1/events', lo)).toMatchObject({ status: 202, du: { nhan: 2, trung: 0 } });
    expect(await demSuKien(t.id, 'ROOT_DETECTED')).toBe(1);
    const lai = JSON.stringify({ events: [suKien(id, 'ROOT_DETECTED')] });
    expect(await goiKy(t, '/v1/events', lai)).toMatchObject({ status: 202, du: { trung: 1 } });
  });

  it('cùng loại từ app chỉ tính điểm một lần / 24 giờ (sự kiện vẫn lưu đủ)', async () => {
    const t = await dangKy();
    const diem = async () => (await db.prepare('SELECT risk_score FROM devices WHERE id = ?').bind(t.id).first<{ risk_score: number }>())?.risk_score;
    const lo = () => JSON.stringify({ events: [suKien('', 'ROOT'), suKien('', 'ROOT')] });
    expect(await goiKy(t, '/v1/events', lo())).toMatchObject({ status: 202, du: { nhan: 2 } });
    expect(await diem()).toBe(25);
    expect(await goiKy(t, '/v1/events', lo())).toMatchObject({ status: 202, du: { nhan: 2 } });
    expect(await diem()).toBe(25);
    const { results } = await db.prepare('SELECT risk_delta FROM security_events WHERE device_id = ? AND type = ? ORDER BY risk_delta DESC').bind(t.id, 'ROOT').all<{ risk_delta: number }>();
    expect(results.map((r) => r.risk_delta)).toEqual([25, 0, 0, 0]);
  });

  it('loại chỉ server sinh -> 422; trường lạ -> 422; không ký -> 401', async () => {
    const t = await dangKy();
    expect((await goiKy(t, '/v1/events', JSON.stringify({ events: [suKien('', 'TOKEN_REUSE')] }))).du).toMatchObject({ status: 422, code: 'loai-chi-server' });
    expect((await goiKy(t, '/v1/events', JSON.stringify({ events: [{ ...suKien('', 'ROOT_DETECTED'), them: 1 }] }))).status).toBe(422);
    expect((await goi('/v1/events', { body: JSON.stringify({ events: [suKien('', 'ROOT_DETECTED')] }), tieuDe: { authorization: `Bearer ${t.token}` } })).status).toBe(401);
  });
});

describe('S10b: /v1/app/su-co', () => {
  const suCo = (kieu: string, nx: string) => ({ loai: 'dart', kieu, thongDiep: 'loi a@b.vn 203.0.113.77', nganXep: nx, phienBan: '0.1.0-beta.12+12', luc: Date.now() });
  it('ký đúng -> 202, gom dấu vết bỏ qua địa chỉ abs, che email / IP; không ký -> 401; lô > 10 -> 422', async () => {
    const t = await dangKy();
    const nx = (abs: string) => `#00 abs ${abs} virt 00000000001b2c _kDartIsolateSnapshotInstructions+0x1b2c\n#01 abs ${abs}ff virt 0000000000aa00 _kDartIsolateSnapshotInstructions+0xaa00`;
    const lo = JSON.stringify({ suCo: [suCo('a1', nx('0000007a1b2c')), suCo('a1', nx('0000009c0000'))] });
    expect(await goiKy(t, '/v1/app/su-co', lo)).toMatchObject({ status: 202, du: { nhan: 2 } });
    const { results } = await db.prepare('SELECT fingerprint, message, device_id FROM app_crashes WHERE device_id = ?').bind(t.id).all<{ fingerprint: string; message: string }>();
    expect(results).toHaveLength(2);
    expect(results[0]?.fingerprint).toBe(results[1]?.fingerprint);
    expect(results[0]?.message).toBe('loi <email> 203.0.113.x');
    expect((await goi('/v1/app/su-co', { body: lo })).status).toBe(401);
    const qua = JSON.stringify({ suCo: Array.from({ length: 11 }, () => suCo('b', '#0 x')) });
    expect((await goiKy(t, '/v1/app/su-co', qua)).status).toBe(422);
    const ev = await db.prepare('SELECT count(*) AS n FROM security_events WHERE device_id = ?').bind(t.id).first<{ n: number }>();
    expect(ev?.n).toBe(0);
  });
});

describe('/v1/status cập nhật phiên bản sau nâng cấp', () => {
  it('header x-app-version hợp lệ -> app_version / build + last_seen mới; sai dạng -> giữ nguyên', async () => {
    const t = await dangKy();
    const doc = () => db.prepare('SELECT app_version, build, last_seen FROM devices WHERE id = ?').bind(t.id).first<{ app_version: string; build: number; last_seen: number }>();
    const truoc = await doc();
    expect(truoc?.app_version).toBe('0.1.0');
    const goiStatus = async (pb: string) =>
      goi('/v1/status', { tieuDe: { ...(await tieuDeKy(t.tb, t.token, { phuongThuc: 'GET', duong: '/v1/status' })), 'x-app-version': pb } });
    expect((await goiStatus('0.1.0-beta.12+12')).status).toBe(200);
    let sau = await doc();
    for (let i = 0; i < 20 && sau?.app_version !== '0.1.0-beta.12'; i++) {
      await new Promise((r) => setTimeout(r, 50));
      sau = await doc();
    }
    expect(sau).toMatchObject({ app_version: '0.1.0-beta.12', build: 12 });
    expect(sau?.last_seen).toBeGreaterThanOrEqual(truoc?.last_seen ?? 0);
    expect((await goiStatus("1'; DROP TABLE devices; --")).status).toBe(200);
    await new Promise((r) => setTimeout(r, 200));
    expect((await doc())?.app_version).toBe('0.1.0-beta.12');
  });
});
