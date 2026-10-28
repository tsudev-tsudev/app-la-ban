import { describe, expect, it } from 'vitest';
import { GioiHanToc } from '../src/do/gioi-han-toc';
import { KhoNonce } from '../src/do/kho-nonce';

/** Storage DO giả trong bộ nhớ (đủ các hàm DO dùng). */
function khoGia() {
  const m = new Map<string, unknown>();
  let hen: number | null = null;
  const kho = {
    get: async <T>(k: string) => m.get(k) as T | undefined,
    put: async (k: string, v: unknown) => void m.set(k, v),
    delete: async (k: string) => m.delete(k),
    list: async <T>({ prefix = '' }: { prefix?: string } = {}) =>
      new Map([...m].filter(([k]) => k.startsWith(prefix)) as [string, T][]),
    getAlarm: async () => hen,
    setAlarm: async (t: number | Date) => void (hen = Number(t)),
  };
  return { kho: kho as never, m, hen: () => hen };
}

const goi = (body: unknown, method = 'POST') =>
  new Request('https://do/x', { method, body: method === 'POST' ? JSON.stringify(body) : null });

describe('KhoNonce', () => {
  it('hẹn dọn ở hạn sớm nhất, alarm xoá nonce hết hạn rồi hẹn lại', async () => {
    let t = 1000;
    const g = khoGia();
    const d = new KhoNonce({ storage: g.kho }, undefined, () => t);
    const n1 = 'a'.repeat(16);
    const n2 = 'b'.repeat(16);
    expect((await d.fetch(goi({ nonce: n1, ttlMs: 5000 }))).status).toBe(200);
    expect((await d.fetch(goi({ nonce: n2, ttlMs: 2000 }))).status).toBe(200);
    expect(g.hen()).toBe(3000);
    t = 4000;
    await d.alarm();
    expect([...g.m.keys()]).toEqual([`n:${n1}`]);
    expect(g.hen()).toBe(6000);
    // Hết hạn -> dùng lại được.
    t = 7000;
    expect((await d.fetch(goi({ nonce: n1 }))).status).toBe(200);
  });
  it('sai phương thức / body', async () => {
    const d = new KhoNonce({ storage: khoGia().kho });
    expect((await d.fetch(goi(null, 'GET'))).status).toBe(405);
    expect((await d.fetch(new Request('https://do/x', { method: 'POST', body: '{' }))).status).toBe(400);
  });
});

describe('GioiHanToc', () => {
  it('đếm theo khoá, đổi cửa sổ thì làm mới; alarm xoá khoá yên', async () => {
    let t = 0;
    const g = khoGia();
    const d = new GioiHanToc({ storage: g.kho }, undefined, () => t);
    const hoi = async (khoa: string, cuaSoMs = 1000) =>
      (await (await d.fetch(goi({ khoa, gioiHan: 2, cuaSoMs }))).json()) as { choPhep: boolean };
    expect((await hoi('a')).choPhep).toBe(true);
    expect((await hoi('a')).choPhep).toBe(true);
    expect((await hoi('a')).choPhep).toBe(false);
    expect((await hoi('a', 5000)).choPhep).toBe(true);
    expect((await hoi('b')).choPhep).toBe(true);
    expect(g.hen()).toBe(2000);
    t = 3000;
    await d.alarm();
    expect([...g.m.keys()]).toEqual(['k:a']);
    expect(g.hen()).toBe(10_000);
  });
  it('lanDauVuot chỉ true ở lần bị từ chối đầu tiên mỗi cửa sổ (RATE_ABUSE không lặp)', async () => {
    let t = 0;
    const d = new GioiHanToc({ storage: khoGia().kho }, undefined, () => t);
    const hoi = async () => ((await (await d.fetch(goi({ khoa: 'a', gioiHan: 1, cuaSoMs: 1000 }))).json()) as { lanDauVuot: boolean }).lanDauVuot;
    expect([await hoi(), await hoi(), await hoi()]).toEqual([false, true, false]);
    t = 2500;
    expect([await hoi(), await hoi()]).toEqual([false, true]);
  });
  it('tham số sai -> 400, GET -> 405', async () => {
    const d = new GioiHanToc({ storage: khoGia().kho });
    for (const b of [{}, { khoa: '', gioiHan: 1, cuaSoMs: 1000 }, { khoa: 'a', gioiHan: 0, cuaSoMs: 1000 }, { khoa: 'a', gioiHan: 1, cuaSoMs: 10 }]) {
      expect((await d.fetch(goi(b))).status).toBe(400);
    }
    expect((await d.fetch(goi(null, 'GET'))).status).toBe(405);
  });
});
