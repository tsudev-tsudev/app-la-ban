// R3c (Q52): nonce + bộ đếm giới hạn trên D1 thật (miniflare, đủ migration).
import type { Miniflare } from 'miniflare';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { donDem } from '../src/d1/don-dep';
import { goiNonce } from '../src/mw/dich-vu';
import { cauDem, quyetDinhDem, type DongDem } from '../src/thuan/dem-d1';
import { LoiApi } from '../src/thuan/loi';
import { taoMf } from './tich-hop/mf';

let mf: Miniflare;
let db: D1Database;
beforeAll(async () => {
  mf = await taoMf();
  db = (await mf.getD1Database('DB')) as unknown as D1Database;
}, 60_000);
afterAll(async () => {
  await mf?.dispose();
});

const N1 = 'nonce-thu-0000000001';
const env = () => ({ MOI_TRUONG: 'test', DB: db });

describe('goiNonce trên D1', () => {
  it('/nonce: lần đầu true, phát lại trong hạn false, hết hạn dùng lại được; phạm vi tách nhau', async () => {
    expect(await goiNonce(env(), 'thiet-bi:a', '/nonce', { nonce: N1, ttlMs: 1000 }, 10_000)).toBe(true);
    expect(await goiNonce(env(), 'thiet-bi:a', '/nonce', { nonce: N1, ttlMs: 1000 }, 10_500)).toBe(false);
    expect(await goiNonce(env(), 'thiet-bi:b', '/nonce', { nonce: N1, ttlMs: 1000 }, 10_500)).toBe(true);
    expect(await goiNonce(env(), 'thiet-bi:a', '/nonce', { nonce: N1, ttlMs: 1000 }, 11_000)).toBe(true);
  });

  it('nonce sai dạng -> false (không chạm D1); thiếu DB -> 503', async () => {
    expect(await goiNonce(env(), 'thiet-bi:a', '/nonce', { nonce: 'ngan' })).toBe(false);
    await expect(goiNonce({ MOI_TRUONG: 'test' }, 'x', '/nonce', { nonce: N1 })).rejects.toBeInstanceOf(LoiApi);
  });

  it('thách thức: /cap rồi /dung đúng một lần; hết hạn hoặc không có -> false; không lẫn với nonce yêu cầu', async () => {
    const t = 'thach-thuc-thu-000000002';
    expect(await goiNonce(env(), 'thach:h1', '/cap', { nonce: t, ttlMs: 5000 }, 1000)).toBe(true);
    expect(await goiNonce(env(), 'thach:h1', '/dung', { nonce: t }, 2000)).toBe(true);
    expect(await goiNonce(env(), 'thach:h1', '/dung', { nonce: t }, 2000)).toBe(false);
    expect(await goiNonce(env(), 'thach:h1', '/cap', { nonce: t, ttlMs: 5000 }, 1000)).toBe(true);
    expect(await goiNonce(env(), 'thach:h1', '/dung', { nonce: t }, 7000)).toBe(false);
    await goiNonce(env(), 'thach:h2', '/nonce', { nonce: t, ttlMs: 5000 }, 1000);
    expect(await goiNonce(env(), 'thach:h2', '/dung', { nonce: t }, 2000)).toBe(false);
  });
});

describe('bộ đếm giới hạn trên D1', () => {
  const dem = async (khoa: string, bayGio: number, cuaSo = 60_000) => {
    const c = cauDem(khoa, bayGio, cuaSo);
    return (await db.prepare(c.sql).bind(...c.thamSo).first<DongDem>()) as DongDem;
  };

  it('cùng cửa sổ cộng dồn; sang cửa sổ kế: dem_truoc = dem cũ; cách >= 2 cửa sổ: làm lại', async () => {
    expect(await dem('k1', 120_000)).toEqual({ bat_dau: 120_000, dem: 1, dem_truoc: 0 });
    expect(await dem('k1', 150_000)).toEqual({ bat_dau: 120_000, dem: 2, dem_truoc: 0 });
    expect(await dem('k1', 185_000)).toEqual({ bat_dau: 180_000, dem: 1, dem_truoc: 2 });
    expect(await dem('k1', 186_000)).toEqual({ bat_dau: 180_000, dem: 2, dem_truoc: 2 });
    expect(await dem('k1', 400_000)).toEqual({ bat_dau: 360_000, dem: 1, dem_truoc: 0 });
  });

  it('quyết định: trong giới hạn cho qua; vượt -> 429 + chờ; lanDauVuot chỉ ở lần vượt đầu', () => {
    expect(quyetDinhDem({ bat_dau: 0, dem: 3, dem_truoc: 0 }, 1000, 3, 60_000)).toEqual({ choPhep: true, thuLaiSau: 0, lanDauVuot: false });
    expect(quyetDinhDem({ bat_dau: 0, dem: 4, dem_truoc: 0 }, 1000, 3, 60_000)).toEqual({ choPhep: false, thuLaiSau: 59, lanDauVuot: true });
    expect(quyetDinhDem({ bat_dau: 0, dem: 5, dem_truoc: 0 }, 1000, 3, 60_000).lanDauVuot).toBe(false);
    // Cửa sổ trước còn trọng số 0,5 x 4 = 2 + dem 2 = 4 > 3: chờ tới khi phần trước <= 1 (75 % cửa sổ).
    const q = quyetDinhDem({ bat_dau: 60_000, dem: 2, dem_truoc: 4 }, 90_000, 3, 60_000);
    expect(q.choPhep).toBe(false);
    expect(q.thuLaiSau).toBe(15);
  });

  it('dọn: xoá nonce + bộ đếm hết hạn, giữ dòng còn hạn', async () => {
    await goiNonce(env(), 'thiet-bi:don', '/nonce', { nonce: 'nonce-don-000000000003', ttlMs: 1000 }, 50_000);
    await dem('k-don', 50_000);
    const truoc = (await db.prepare('SELECT count(*) AS n FROM nonce_dung').first<{ n: number }>())?.n ?? 0;
    const kq = await donDem(db, 10_000_000);
    expect(kq.xoa).toBeGreaterThanOrEqual(2);
    expect((await db.prepare('SELECT count(*) AS n FROM nonce_dung').first<{ n: number }>())?.n).toBeLessThan(truoc);
    expect(await db.prepare("SELECT 1 FROM gioi_han_dem WHERE khoa = 'k-don'").first()).toBeNull();
  });
});

describe('docQuaColo (Cache API colo)', () => {
  it('/v1/config: lần sau trong TTL đọc từ cache colo dù KV đã đổi (cùng độ cũ tối đa như cacheTtl KV)', async () => {
    const mfc = await taoMf(undefined, { cache: true });
    try {
      const kv = (await mfc.getKVNamespace('CAU_HINH')) as unknown as KVNamespace;
      const goi = { kid: 'app-1', duLieu: 'eyJ2IjoxfQ', chuKy: 'A'.repeat(86) };
      await kv.put('app-cau-hinh', JSON.stringify(goi));
      const doc = async () => (await mfc.dispatchFetch('https://compass-api.tsudev.com/v1/config', { headers: { 'cf-connecting-ip': '198.51.100.5' } })).json();
      expect(await doc()).toEqual(goi);
      await kv.put('app-cau-hinh', JSON.stringify({ ...goi, kid: 'app-2' }));
      await new Promise((r) => setTimeout(r, 50));
      expect(await doc()).toEqual(goi);
    } finally {
      await mfc.dispose();
    }
  }, 60_000);
});
