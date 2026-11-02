import { gunzipSync, gzipSync } from 'node:zlib';
import type { Miniflare } from 'miniflare';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { danhGiaDotBien, khungVuaDong, phanLoai, sqlDotBien } from '../src/thuan/dot-bien';
import {
  dauChuoiGoc,
  docDauChuoi,
  kiemChuoiDoan,
  KHOA_DAU_CHUOI,
  taoDoan,
  type DoanDaGhi,
} from '../src/thuan/nhat-ky-bat-bien';
import { BANG_SAO_LUU, docTieuDe, dongGoi, dongNdjson, laLuotSaoLuu, moGoi, sqlKhoiPhuc } from '../src/thuan/sao-luu';
import { taoMf } from './tich-hop/mf';

const T0 = Date.UTC(2026, 10, 2, 3, 0);

function co<T>(v: T | null | undefined): T {
  if (v === null || v === undefined) throw new Error('thiếu giá trị');
  return v;
}

async function capKhoa(): Promise<{ congKhai: string; rieng: Uint8Array<ArrayBuffer> }> {
  const k = (await crypto.subtle.generateKey(
    { name: 'RSA-OAEP', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
    true,
    ['encrypt', 'decrypt'],
  )) as CryptoKeyPair;
  const spki = new Uint8Array((await crypto.subtle.exportKey('spki', k.publicKey)) as ArrayBuffer);
  return {
    congKhai: Buffer.from(spki).toString('base64'),
    rieng: new Uint8Array((await crypto.subtle.exportKey('pkcs8', k.privateKey)) as ArrayBuffer),
  };
}

describe('S10a: nhật ký bất biến (thuần)', () => {
  it('đoạn nối chuỗi, con trỏ + mốc neo audit tiến; không dòng -> không đoạn', async () => {
    const d0 = dauChuoiGoc();
    expect(await taoDoan(d0, [], T0)).toBeNull();
    const a = await taoDoan(
      d0,
      [
        { bang: 'audit_logs', so: 3, dong: { id: 'a', hash_self: 'f'.repeat(64) } },
        { bang: 'security_events', so: 9, dong: { id: 'e', ip: '203.0.113.0/24' } },
      ],
      T0,
    );
    expect(a?.khoa).toBe('nhat-ky/2026/11/02/0000000001.ndjson');
    expect(a?.dau).toMatchObject({ so: 1, conTro: { audit_logs: 3, security_events: 9, rule_hits: 0 }, auditCuoi: 'f'.repeat(64), auditSoDong: 1 });
    const b = await taoDoan(co(a).dau, [{ bang: 'rule_hits', so: 1, dong: { rule_id: 'r' } }], T0 + 300_000);
    expect(b?.meta.hash_prev).toBe(a?.dau.hash);
    const ds: DoanDaGhi[] = [co(a), co(b)].map((x) => ({ so: x.dau.so, hash_prev: x.meta.hash_prev, hash_self: x.meta.hash_self, ndjson: x.ndjson }));
    expect(await kiemChuoiDoan(ds)).toBe(-1);
    expect(await kiemChuoiDoan([{ ...co(ds[0]), ndjson: co(ds[0]).ndjson.replace('"e"', '"x"') }, co(ds[1])])).toBe(1);
    expect(await kiemChuoiDoan([co(ds[1])])).toBe(2);
    expect(await kiemChuoiDoan([co(ds[1])], co(ds[0]).hash_self, 2)).toBe(-1);
  });

  it('đầu chuỗi: rỗng -> gốc; hỏng -> null (không tự tạo chuỗi mới)', () => {
    expect(docDauChuoi(null)).toEqual(dauChuoiGoc());
    expect(docDauChuoi('{')).toBeNull();
    expect(docDauChuoi(JSON.stringify({ so: 1, hash: 'x' }))).toBeNull();
    expect(docDauChuoi(JSON.stringify({ so: 2, hash: 'a'.repeat(64), conTro: { audit_logs: 5 } }))?.conTro).toEqual({ audit_logs: 5, security_events: 0, rule_hits: 0 });
  });
});

describe('S10a: sao lưu mã hoá lai (thuần)', () => {
  it('đóng gói -> mở bằng khoá riêng ra đúng ndjson; tiêu đề đọc được không cần khoá; sửa tiêu đề -> hỏng', async () => {
    const { congKhai, rieng } = await capKhoa();
    const nd = dongNdjson('devices', { id: 'd1', model: "O'Neil" }) + dongNdjson('audit_logs', { id: 'a1' });
    const tep = await dongGoi(nd, new Uint8Array(gzipSync(nd)), { devices: 1, audit_logs: 1 }, congKhai, 'test', T0);
    const { tieuDe } = docTieuDe(tep);
    expect(tieuDe).toMatchObject({ v: 1, moiTruong: 'test', bang: { devices: 1, audit_logs: 1 } });
    expect(tieuDe.kid).toMatch(/^[0-9a-f]{16}$/);
    const mo = await moGoi(tep, rieng);
    expect(gunzipSync(mo.nen).toString()).toBe(nd);
    const sua = tep.slice();
    sua[12] = co(sua[12]) ^ 1;
    await expect(moGoi(sua, rieng)).rejects.toThrow();
    await expect(moGoi(tep, (await capKhoa()).rieng)).rejects.toThrow();
  });

  it('SQL khôi phục: thoát nháy, giữ thứ tự, không xoá audit_logs, từ chối bảng / cột lạ', () => {
    const nd = dongNdjson('rules', { id: 'r1', name: "a'b" }) + dongNdjson('audit_logs', { id: 'a', ts: 1, before: null });
    const { sql, dem } = sqlKhoiPhuc(nd);
    expect(dem).toEqual({ rules: 1, audit_logs: 1 });
    expect(sql).toContain(`INSERT INTO rules ("id", "name") VALUES ('r1', 'a''b');`);
    expect(sql).toContain('DELETE FROM rules;');
    expect(sql).not.toContain('DELETE FROM audit_logs');
    expect(() => sqlKhoiPhuc(dongNdjson('sqlite_master', { a: 1 }))).toThrow('bang-la');
    expect(() => sqlKhoiPhuc(`${JSON.stringify({ t: 'rules', r: { 'id); DROP': 1 } })}\n`)).toThrow('cot-la');
  });

  it('cửa sổ 19:30-19:59 UTC', () => {
    expect(laLuotSaoLuu(Date.UTC(2026, 10, 2, 19, 30))).toBe(true);
    expect(laLuotSaoLuu(Date.UTC(2026, 10, 2, 19, 55))).toBe(true);
    expect(laLuotSaoLuu(Date.UTC(2026, 10, 2, 19, 25))).toBe(false);
    expect(laLuotSaoLuu(Date.UTC(2026, 10, 2, 20, 30))).toBe(false);
  });
});

describe('S10a: tăng đột biến (thuần)', () => {
  it('phân loại mã HTTP / sự kiện riêng', () => {
    expect(phanLoai('/v1/x', '503')).toEqual(['loi-5xx']);
    expect(phanLoai('/v1/x', '403')).toEqual(['loi-4xx', 'tu-choi']);
    expect(phanLoai('/v1/x', '404')).toEqual(['loi-4xx']);
    expect(phanLoai('attest', '')).toEqual(['attest-loi']);
    expect(phanLoai('csp', 'enforce')).toEqual([]);
    expect(phanLoai('/v1/x', '200')).toEqual([]);
  });

  it('vượt ngưỡng tuyệt đối VÀ hệ số so với nền mới báo', () => {
    const k = khungVuaDong(Date.UTC(2026, 10, 2, 3, 7));
    expect(k).toBe('2026-11-02 03:00:00');
    const nen = Array.from({ length: 12 }, (_, i) => ({ khung: `2026-11-02 02:${String(i * 5).padStart(2, '0')}:00`, i: '/v1/x', s: '500', n: 2 }));
    expect(danhGiaDotBien([...nen, { khung: k, i: '/v1/x', s: '500', n: '30' }], k)).toEqual([{ chiSo: 'loi-5xx', hienTai: 30, nen: 2 }]);
    expect(danhGiaDotBien([...nen, { khung: k, i: '/v1/x', s: '500', n: 5 }], k)).toEqual([]);
    expect(danhGiaDotBien([{ khung: k, i: 'attest', s: '', n: 12 }, { khung: '2026-11-02 03:05:00', i: '/v1/x', s: '500', n: 99 }], k)).toEqual([
      { chiSo: 'attest-loi', hienTai: 12, nen: 0 },
    ]);
    expect(() => sqlDotBien('x; DROP')).toThrow();
  });
});

describe('S10a: tích hợp Worker (D1 + R2 trong workerd)', () => {
  let mf: Miniflare;
  let rieng: Uint8Array<ArrayBuffer>;
  const goc = 'https://compass-api.tsudev.com';
  const goi = (duong: string, init?: RequestInit) => mf.dispatchFetch(`${goc}${duong}`, { method: 'POST', ...init } as never);

  beforeAll(async () => {
    const k = await capKhoa();
    rieng = k.rieng;
    mf = await taoMf(undefined, { bindings: { KHOA_SAO_LUU: k.congKhai } });
  }, 60_000);
  afterAll(async () => {
    await mf?.dispose();
  });

  it('bảng sao lưu + bảng tạm bỏ qua = toàn bộ bảng D1 (migration mới phải khai báo)', async () => {
    const db = await mf.getD1Database('DB');
    const { results } = await db
      .prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE '\\_%' ESCAPE '\\' AND name NOT LIKE 'sqlite%' AND name <> 'd1_migrations'")
      .all<{ name: string }>();
    const boQua = ['sessions', 'idempotency_keys', 'admin_challenges', 'admin_sessions', 'nonce_dung', 'gioi_han_dem'];
    expect(results.map((r) => r.name).sort()).toEqual([...BANG_SAO_LUU, ...boQua].sort());
  });

  it('xuất nhật ký theo lượt: đoạn nối chuỗi, IP sự kiện rút gọn, lượt không dữ liệu không ghi đoạn', async () => {
    const db = await mf.getD1Database('DB');
    await db.prepare("INSERT INTO devices (id, installation_id_hash, platform, first_seen, last_seen) VALUES ('d-s10', 'h-s10', 'android', 1, 1)").run();
    await db
      .prepare("INSERT INTO security_events (id, device_id, type, severity, ip, ts) VALUES ('e1', 'd-s10', 'thu', 'low', '203.0.113.77', 1)")
      .run();
    await goi('/thu/audit', { headers: { 'content-type': 'application/json' }, body: JSON.stringify({ actor: 'a@x', ts: 1 }) });
    const r1 = (await (await goi(`/thu/nhat-ky?bayGio=${T0}`)).json()) as { so: number; dong: number };
    expect(r1).toMatchObject({ so: 1, dong: 2 });
    expect((await (await goi(`/thu/nhat-ky?bayGio=${T0}`)).json()) as object).toMatchObject({ so: 1, dong: 0 });
    await db.prepare("INSERT INTO security_events (id, device_id, type, severity, ts) VALUES ('e2', 'd-s10', 'thu', 'low', 2)").run();
    expect((await (await goi(`/thu/nhat-ky?bayGio=${T0}`)).json()) as object).toMatchObject({ so: 2, dong: 1 });

    const khoa = ((await (await mf.dispatchFetch(`${goc}/thu/r2`)).json()) as string[]).filter((k) => k.startsWith('nhat-ky/')).sort();
    expect(khoa).toHaveLength(2);
    const ds: DoanDaGhi[] = [];
    for (const k of khoa) {
      const res = await mf.dispatchFetch(`${goc}/thu/r2?k=${encodeURIComponent(k)}`);
      const meta = JSON.parse(res.headers.get('x-meta') ?? '{}') as Record<string, string>;
      ds.push({ so: Number(meta.so), hash_prev: co(meta.hash_prev), hash_self: co(meta.hash_self), ndjson: await res.text() });
    }
    expect(await kiemChuoiDoan(ds)).toBe(-1);
    expect(co(ds[0]).ndjson).toContain('203.0.113.0/24');
    expect(co(ds[0]).ndjson).not.toContain('203.0.113.77');
    const dau = JSON.parse(await (await mf.dispatchFetch(`${goc}/thu/r2?k=${KHOA_DAU_CHUOI}`)).text()) as { auditSoDong: number; hash: string };
    expect(dau).toMatchObject({ auditSoDong: 1, hash: co(ds[1]).hash_self });
  });

  it('đầu chuỗi hỏng -> lượt xuất lỗi, không tạo chuỗi mới', async () => {
    const m2 = await taoMf();
    try {
      await m2.dispatchFetch(`${goc}/thu/r2?k=${KHOA_DAU_CHUOI}`, { method: 'PUT', body: '{hong' });
      expect((await m2.dispatchFetch(`${goc}/thu/nhat-ky?bayGio=${T0}`, { method: 'POST' })).status).toBe(500);
    } finally {
      await m2.dispose();
    }
  });

  it('sao lưu ngày: mã hoá, mỗi ngày một bản; giải mã + SQL khôi phục đủ dòng', async () => {
    const r = (await (await goi(`/thu/sao-luu?bayGio=${T0}`)).json()) as { khoa: string; dong: number };
    expect(r.khoa).toBe('sao-luu/2026-11-02.lbsl');
    expect(r.dong).toBeGreaterThan(5);
    expect((await (await goi(`/thu/sao-luu?bayGio=${T0 + 600_000}`)).json()) as object).toEqual({ bo: 'da-co' });
    const tep = new Uint8Array(await (await mf.dispatchFetch(`${goc}/thu/r2?k=${r.khoa}`)).arrayBuffer());
    const { tieuDe, nen } = await moGoi(tep, rieng);
    const nd = gunzipSync(nen).toString();
    const { dem } = sqlKhoiPhuc(nd);
    expect(dem.devices).toBe(1);
    expect(dem.audit_logs).toBe(1);
    expect(Object.values(dem).reduce((a, b) => a + b, 0)).toBe(r.dong);
    expect(Object.fromEntries(Object.entries(tieuDe.bang).filter(([, n]) => n))).toEqual(dem);
  });
});
