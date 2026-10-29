// S9: khiên web phía Worker - phần thuần (gói cấu hình, tín hiệu, URL ký) + tích hợp workerd (Miniflare).
import type { Miniflare } from 'miniflare';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { goiCauHinhHopLe, schemaTinHieuWeb, suKienTuTinHieu } from '../src/thuan/khien-web';
import { HAN_TOI_DA_MS, khoaHopLe, kiemUrl, kyUrl, laHotlink, maxAgeGiay } from '../src/thuan/url-ky';
import { NGUON_WEB } from '../src/thuan/cors';
import { taoMf } from './tich-hop/mf';

const GOI = { kid: 'web-1', duLieu: 'eyJ2IjoxfQ', chuKy: 'a'.repeat(86) };
const TIN_HIEU = { trang: 'landing', loai: 'devtools', duongDan: '/tai-ve', tinHieu: { kich_thuoc: true, diem: 0, phim: 1, menu: 0 } };

describe('goiCauHinhHopLe', () => {
  it('giữ gói đúng hình dạng, bỏ trường lạ / sai dạng / quá lớn', () => {
    expect(goiCauHinhHopLe(JSON.stringify(GOI))).toBe(JSON.stringify(GOI));
    expect(goiCauHinhHopLe(JSON.stringify({ ...GOI, x: 1 }))).toBeNull();
    expect(goiCauHinhHopLe(JSON.stringify({ ...GOI, chuKy: 'a+b' }))).toBeNull();
    expect(goiCauHinhHopLe('{')).toBeNull();
    expect(goiCauHinhHopLe(null)).toBeNull();
    expect(goiCauHinhHopLe('x'.repeat(9000))).toBeNull();
  });
});

describe('tín hiệu web', () => {
  it('schema chặt, đường dẫn chỉ ký tự an toàn', () => {
    expect(schemaTinHieuWeb.safeParse(TIN_HIEU).success).toBe(true);
    expect(schemaTinHieuWeb.safeParse({ ...TIN_HIEU, ua: 'x' }).success).toBe(false);
    expect(schemaTinHieuWeb.safeParse({ ...TIN_HIEU, duongDan: '/a?email=x@y' }).success).toBe(false);
    expect(schemaTinHieuWeb.safeParse({ ...TIN_HIEU, tinHieu: { ...TIN_HIEU.tinHieu, diem: -1 } }).success).toBe(false);
  });
  it('-> sự kiện WEB_DEVTOOLS', () => {
    const e = suKienTuTinHieu(schemaTinHieuWeb.parse(TIN_HIEU), 'id1');
    expect(e).toEqual({ id: 'id1', type: 'WEB_DEVTOOLS', severity: 'low', signals: { trang: 'landing', duong_dan: '/tai-ve', kich_thuoc: true, diem: 0, phim: 1, menu: 0 } });
  });
});

describe('URL ký', () => {
  it('khoá tài nguyên: chặn đi ngược thư mục / ký tự lạ', () => {
    expect(khoaHopLe('soc/anh-1.png')).toBe(true);
    for (const k of ['../x', 'a/../b', 'a//b', '/a', 'A.png', 'a b', 'a/./b', '']) expect(khoaHopLe(k)).toBe(false);
  });
  it('ký rồi kiểm: đúng / hết hạn / sửa khoá / sửa hạn / bí mật khác / hạn quá xa', async () => {
    const bayGio = 1_000_000;
    const url = new URL(await kyUrl('bm', 'a/b.png', bayGio + 60_000), 'https://x');
    const het = url.searchParams.get('het') ?? undefined;
    const ky = url.searchParams.get('ky') ?? undefined;
    expect(url.pathname).toBe('/v1/tn/a/b.png');
    expect(await kiemUrl('bm', 'a/b.png', het, ky, bayGio)).toBe('ok');
    expect(await kiemUrl('bm', 'a/b.png', het, ky, bayGio + 60_000)).toBe('het-han');
    expect(await kiemUrl('bm', 'a/c.png', het, ky, bayGio)).toBe('sai');
    expect(await kiemUrl('bm', 'a/b.png', String(bayGio + 61_000), ky, bayGio)).toBe('sai');
    expect(await kiemUrl('khac', 'a/b.png', het, ky, bayGio)).toBe('sai');
    expect(await kiemUrl('bm', 'a/b.png', het, undefined, bayGio)).toBe('sai');
    const xa = bayGio + HAN_TOI_DA_MS + 1;
    const u2 = new URL(await kyUrl('bm', 'a/b.png', xa), 'https://x');
    expect(await kiemUrl('bm', 'a/b.png', String(xa), u2.searchParams.get('ky') ?? undefined, bayGio)).toBe('sai');
  });
  it('hotlink theo Referer / Sec-Fetch-Site', () => {
    expect(laHotlink('cross-site', 'https://kẻ-lạ.example/', NGUON_WEB)).toBe(true);
    expect(laHotlink('same-site', 'https://compass-admin.tsudev.com/x', NGUON_WEB)).toBe(false);
    expect(laHotlink('same-site', 'https://ubnd.tsudev.com/', NGUON_WEB)).toBe(true);
    expect(laHotlink('cross-site', undefined, NGUON_WEB)).toBe(true);
    expect(laHotlink('same-site', undefined, NGUON_WEB)).toBe(false);
    expect(laHotlink(undefined, undefined, NGUON_WEB)).toBe(false);
    expect(laHotlink(undefined, 'rác', NGUON_WEB)).toBe(true);
  });
  it('max-age không vượt hạn, trần 1 giờ', () => {
    expect(maxAgeGiay(10_500, 0)).toBe(10);
    expect(maxAgeGiay(9e9, 0)).toBe(3600);
    expect(maxAgeGiay(0, 5)).toBe(0);
  });
});

describe('tích hợp workerd', () => {
  let mf: Miniflare;
  const goc = 'https://compass-api.tsudev.com';
  const LANDING = 'https://compass.tsudev.com';
  const ip = (n: number) => ({ 'cf-connecting-ip': `203.0.113.${n}` });

  beforeAll(async () => {
    mf = await taoMf();
  }, 60_000);
  afterAll(async () => {
    await mf?.dispose();
  });

  it('GET /v1/web/cau-hinh: 404 khi chưa có / sai dạng, 200 nguyên văn + CORS + cache khi có', async () => {
    const kv = await mf.getKVNamespace('CAU_HINH');
    expect((await mf.dispatchFetch(`${goc}/v1/web/cau-hinh`, { headers: ip(1) })).status).toBe(404);
    await kv.put('web-khien', '{"kid":1}');
    expect((await mf.dispatchFetch(`${goc}/v1/web/cau-hinh`, { headers: ip(1) })).status).toBe(404);
    await kv.put('web-khien', JSON.stringify(GOI));
    const res = await mf.dispatchFetch(`${goc}/v1/web/cau-hinh`, { headers: { ...ip(1), origin: LANDING } });
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual(GOI);
    expect(res.headers.get('access-control-allow-origin')).toBe(LANDING);
    expect(res.headers.get('cache-control')).toBe('public, max-age=300');
    const la = await mf.dispatchFetch(`${goc}/v1/web/cau-hinh`, { headers: { ...ip(1), origin: 'https://evil.example' } });
    expect(la.headers.get('access-control-allow-origin')).toBeNull();
  });

  it('POST /v1/web/signals: preflight, thiếu Origin -> 403, đúng -> 202 + sự kiện WEB_DEVTOOLS theo IP', async () => {
    const pre = await mf.dispatchFetch(`${goc}/v1/web/signals`, {
      method: 'OPTIONS',
      headers: { ...ip(2), origin: LANDING, 'access-control-request-method': 'POST', 'access-control-request-headers': 'content-type' },
    });
    expect(pre.status).toBe(204);
    expect(pre.headers.get('access-control-allow-origin')).toBe(LANDING);
    const gui = (them: Record<string, string>, body: unknown = TIN_HIEU) =>
      mf.dispatchFetch(`${goc}/v1/web/signals`, { method: 'POST', headers: { 'content-type': 'application/json', ...them }, body: JSON.stringify(body) });
    expect((await gui(ip(2))).status).toBe(403);
    expect((await gui({ ...ip(2), origin: 'https://evil.example' })).status).toBe(403);
    expect((await gui({ ...ip(2), origin: LANDING }, { ...TIN_HIEU, x: 1 })).status).toBe(422);
    const ok = await gui({ ...ip(2), origin: LANDING });
    expect(ok.status).toBe(202);
    const db = await mf.getD1Database('DB');
    let hang: { type: string; signals: string; device_id: string | null } | null = null;
    for (let i = 0; i < 20 && !hang; i++) {
      hang = await db.prepare("SELECT type, signals, device_id FROM security_events WHERE ip = '203.0.113.2'").first();
      if (!hang) await new Promise((r) => setTimeout(r, 50));
    }
    expect(hang?.type).toBe('WEB_DEVTOOLS');
    expect(hang?.device_id).toBeNull();
    expect(JSON.parse(hang?.signals ?? '{}')).toMatchObject({ trang: 'landing', duong_dan: '/tai-ve', kich_thuoc: true });
  });

  it('GET /v1/tn/*: URL ký đúng -> 200; sai / hết hạn / hotlink / thiếu vật -> 403 / 410 / 403 / 404', async () => {
    const r2 = await mf.getR2Bucket('CDN');
    await r2.put('ky/soc/anh.png', new Uint8Array([137, 80, 78, 71]), { httpMetadata: { contentType: 'image/png' } });
    const bayGio = Date.now();
    const url = await kyUrl('khoa-url-ky-thu', 'soc/anh.png', bayGio + 120_000);
    const ok = await mf.dispatchFetch(`${goc}${url}`, { headers: ip(3) });
    expect(ok.status).toBe(200);
    expect(ok.headers.get('content-type')).toBe('image/png');
    expect(ok.headers.get('cache-control')).toMatch(/^private, max-age=1[01]\d$/);
    expect(new Uint8Array(await ok.arrayBuffer())).toEqual(new Uint8Array([137, 80, 78, 71]));
    expect((await mf.dispatchFetch(`${goc}${url.replace('anh.png', 'anh2.png')}`, { headers: ip(3) })).status).toBe(403);
    expect((await mf.dispatchFetch(`${goc}${url}`, { headers: { ...ip(3), referer: 'https://evil.example/' } })).status).toBe(403);
    const cu = await kyUrl('khoa-url-ky-thu', 'soc/anh.png', bayGio - 1_000);
    expect((await mf.dispatchFetch(`${goc}${cu}`, { headers: ip(3) })).status).toBe(410);
    const thieu = await kyUrl('khoa-url-ky-thu', 'soc/khong-co.png', bayGio + 60_000);
    expect((await mf.dispatchFetch(`${goc}${thieu}`, { headers: ip(3) })).status).toBe(404);
  });
});
