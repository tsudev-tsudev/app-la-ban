import type { Miniflare } from 'miniflare';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { tachSql, taoMf } from './tich-hop/mf';

let mf: Miniflare;
const goc = 'https://compass-api.tsudev.com';
const ip = (n: number) => ({ 'cf-connecting-ip': `198.51.100.${n}` });
const post = (duong: string, body: unknown, them: Record<string, string> = {}) =>
  mf.dispatchFetch(`${goc}${duong}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...them },
    body: typeof body === 'string' ? body : JSON.stringify(body),
  });

beforeAll(async () => {
  mf = await taoMf();
}, 60_000);
afterAll(async () => {
  await mf?.dispose();
});

describe('tachSql', () => {
  it('giữ khối trigger BEGIN..END, bỏ chú thích', () => {
    const ds = tachSql('-- x\nCREATE TABLE a (b INT);\nCREATE TRIGGER t BEFORE UPDATE ON a\nBEGIN\n  SELECT 1;\nEND;\n');
    expect(ds).toEqual(['CREATE TABLE a (b INT);', 'CREATE TRIGGER t BEFORE UPDATE ON a\nBEGIN\n  SELECT 1;\nEND;']);
  });
});

describe('migration D1 0001', () => {
  it('đủ bảng Spec §6.4 + idempotency', async () => {
    const db = await mf.getD1Database('DB');
    const { results } = await db.prepare("SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE '\\_%' ESCAPE '\\' AND name NOT LIKE 'sqlite%' ORDER BY name").all<{ name: string }>();
    expect(results.map((r) => r.name)).toEqual([
      'admin_users', 'appeals', 'audit_logs', 'device_ips', 'devices', 'enforcements', 'idempotency_keys', 'rules', 'security_events', 'sessions',
    ]);
  });
  it('ràng buộc: enforcement phải có hạn, người duyệt khác người tạo; vai trò hợp lệ', async () => {
    const db = await mf.getD1Database('DB');
    const enf = (het: number, duyet: string | null) =>
      db.prepare("INSERT INTO enforcements (id, target_type, target_value, action, reason, created_by, approved_by, created_at, expires_at, source) VALUES (?, 'ip', '1.2.3.4', 'block', 'thu', 'a', ?, 100, ?, 'manual')").bind(crypto.randomUUID(), duyet, het).run();
    await expect(enf(50, null)).rejects.toThrow(/CHECK/);
    await expect(enf(200, 'a')).rejects.toThrow(/CHECK/);
    await expect(enf(200, 'b')).resolves.toBeTruthy();
    await expect(db.prepare("INSERT INTO admin_users (id, email, role) VALUES ('u', 'x@y', 'god')").run()).rejects.toThrow(/CHECK/);
  });
});

describe('lỗi RFC 7807 không lộ chi tiết', () => {
  it('500 chung chung + header bảo mật + x-request-id', async () => {
    const res = await post('/thu/loi', {}, { ...ip(1), 'idempotency-key': crypto.randomUUID() });
    expect(res.status).toBe(500);
    const vb = await res.text();
    expect(vb).not.toMatch(/BI_MAT|stack|at |\.ts/);
    expect(JSON.parse(vb)).toMatchObject({ type: 'about:blank', title: 'Internal Server Error', status: 500 });
    expect(res.headers.get('content-type')).toContain('application/problem+json');
    expect(res.headers.get('x-request-id')).toBeTruthy();
    expect(res.headers.get('x-content-type-options')).toBe('nosniff');
  });
  it('415 / 413 / 400 / 422 / 428 theo thứ tự kiểm', async () => {
    // Mỗi lệnh một IP riêng: route thử giới hạn 4 yêu cầu / phút / IP.
    let n = 20;
    const k = () => ({ ...ip(n++), 'idempotency-key': crypto.randomUUID() });
    const sai = await mf.dispatchFetch(`${goc}/thu/ghi`, { method: 'POST', headers: { ...k(), 'content-type': 'text/plain' }, body: 'x' });
    expect([sai.status, ((await sai.json()) as { code: string }).code]).toEqual([415, 'can-json']);
    expect((await post('/thu/ghi', JSON.stringify({ ten: 'x'.repeat(20_000) }), k())).status).toBe(413);
    expect((await post('/thu/ghi', '{"ten":', k())).status).toBe(400);
    const la = await post('/thu/ghi', { ten: 'a', vaiTro: 'admin' }, k());
    expect(la.status).toBe(422);
    expect(await la.text()).not.toContain('vaiTro');
    const thieu = await post('/thu/ghi', { ten: 'a' }, ip(n++));
    expect([thieu.status, ((await thieu.json()) as { code: string }).code]).toEqual([428, 'thieu-idempotency-key']);
    expect((await post('/thu/ghi', { ten: 'a' }, { ...ip(n++), 'idempotency-key': 'abc' })).status).toBe(400);
  });
});

describe('Idempotency-Key (API-03) trên D1 thật', () => {
  it('phát lại cùng phản hồi, handler chạy đúng một lần; khác nội dung -> 422', async () => {
    const dem = async () => ((await (await mf.dispatchFetch(`${goc}/thu/dem`, { headers: ip(3) })).json()) as { soLanXuLy: number }).soLanXuLy;
    const truoc = await dem();
    const k = { ...ip(3), 'idempotency-key': crypto.randomUUID() };
    const a = await post('/thu/ghi', { ten: 'mot' }, k);
    expect(a.status).toBe(201);
    const ba = await a.text();
    const b = await post('/thu/ghi', { ten: 'mot' }, k);
    expect(b.status).toBe(201);
    expect(b.headers.get('idempotent-replayed')).toBe('true');
    expect(await b.text()).toBe(ba);
    expect(await dem()).toBe(truoc + 1);
    const c = await post('/thu/ghi', { ten: 'hai' }, k);
    expect([c.status, ((await c.json()) as { code: string }).code]).toEqual([422, 'idempotency-key-da-dung']);
  });
  it('khoá theo phạm vi: IP khác dải cùng khoá không lẫn', async () => {
    const khoa = crypto.randomUUID();
    const a = await post('/thu/ghi', { ten: 'x' }, { 'cf-connecting-ip': '203.0.113.9', 'idempotency-key': khoa });
    const b = await post('/thu/ghi', { ten: 'x' }, { 'cf-connecting-ip': '192.0.2.9', 'idempotency-key': khoa });
    expect(b.headers.get('idempotent-replayed')).toBeNull();
    expect(await a.text()).not.toBe(await b.text());
  });
});

describe('giới hạn tốc độ (API-01)', () => {
  it('DO GioiHanToc: quá 4/phút theo IP -> 429 + Retry-After', async () => {
    const kq: number[] = [];
    let thuLai = '';
    for (let i = 0; i < 6; i++) {
      const res = await post('/thu/ghi', { ten: `r${i}` }, { ...ip(40), 'idempotency-key': crypto.randomUUID() });
      kq.push(res.status);
      thuLai = res.headers.get('retry-after') ?? '';
    }
    expect(kq).toEqual([201, 201, 201, 201, 429, 429]);
    expect(Number(thuLai)).toBeGreaterThan(0);
    // IP khác không bị ảnh hưởng.
    expect((await post('/thu/ghi', { ten: 'k' }, { ...ip(41), 'idempotency-key': crypto.randomUUID() })).status).toBe(201);
  });
  it('Rate Limiting binding RL_IP chặn lũ theo IP ở mọi route', async () => {
    const mf2 = await taoMf({ limit: 3, period: 60 });
    try {
      const ds: number[] = [];
      for (let i = 0; i < 5; i++) ds.push((await mf2.dispatchFetch(`${goc}/v1/health`, { headers: ip(77) })).status);
      expect(ds.slice(0, 3)).toEqual([200, 200, 200]);
      expect(ds.slice(3)).toEqual([429, 429]);
    } finally {
      await mf2.dispose();
    }
  }, 60_000);
});

describe('KhoNonce (chống replay)', () => {
  it('nonce dùng một lần', async () => {
    const n = { nonce: crypto.randomUUID().replace(/-/g, '') };
    expect((await post('/thu/nonce', n, ip(5))).status).toBe(200);
    expect((await post('/thu/nonce', n, ip(5))).status).toBe(409);
    expect((await post('/thu/nonce', { nonce: 'ngan' }, ip(5))).status).toBe(400);
  });
});

describe('audit log chuỗi băm (DAT-02) trên D1', () => {
  it('ghi nối tiếp, kiểm nguyên vẹn; UPDATE / DELETE bị trigger chặn', async () => {
    for (let i = 0; i < 3; i++) expect((await post('/thu/audit', { actor: `a${i}`, ts: i }, ip(6))).status).toBe(200);
    const kiem = (await (await mf.dispatchFetch(`${goc}/thu/audit`, { headers: ip(6) })).json()) as { loi: number };
    expect(kiem.loi).toBe(-1);
    const db = await mf.getD1Database('DB');
    await expect(db.prepare("UPDATE audit_logs SET actor = 'x'").run()).rejects.toThrow(/chi them/);
    await expect(db.prepare('DELETE FROM audit_logs').run()).rejects.toThrow(/chi them/);
  });
  it('ghi đồng thời không rẽ nhánh chuỗi', async () => {
    const ds = await Promise.all([0, 1, 2, 3].map((i) => post('/thu/audit', { actor: `ss${i}`, ts: 100 + i }, ip(7))));
    expect(ds.every((r) => r.status === 200)).toBe(true);
    const kiem = (await (await mf.dispatchFetch(`${goc}/thu/audit`, { headers: ip(7) })).json()) as { loi: number };
    expect(kiem.loi).toBe(-1);
  });
});

describe('cron dọn dữ liệu (Spec §6.4, DAT-01)', () => {
  it('xoá sự kiện > 180 ngày, rút gọn IP > 90 ngày trừ thiết bị bị enforcement', async () => {
    const db = await mf.getD1Database('DB');
    const NGAY = 86_400_000;
    const bayGio = 400 * NGAY;
    const tb = (id: string) => db.prepare("INSERT INTO devices (id, installation_id_hash, platform, first_seen, last_seen) VALUES (?, ?, 'android', 0, 0)").bind(id, `h-${id}`);
    const ipDong = (d: string, ipx: string, last: number) => db.prepare('INSERT INTO device_ips (device_id, ip, first_seen, last_seen, count) VALUES (?, ?, ?, ?, 2)').bind(d, ipx, last - 5, last);
    await db.batch([
      tb('d1'),
      tb('d2'),
      ipDong('d1', '10.1.2.3', bayGio - 100 * NGAY),
      ipDong('d1', '10.1.2.4', bayGio - 95 * NGAY),
      ipDong('d1', '10.9.9.9', bayGio - 10 * NGAY),
      ipDong('d2', '10.5.5.5', bayGio - 100 * NGAY),
      db.prepare("INSERT INTO enforcements (id, target_type, target_value, action, reason, created_by, created_at, expires_at, source) VALUES ('e1', 'device', 'd2', 'restrict', 'thu', 'auto', 1, 2, 'auto')"),
      db.prepare("INSERT INTO security_events (id, device_id, type, severity, ts) VALUES ('s-cu', 'd1', 'X', 'low', ?), ('s-moi', 'd1', 'X', 'low', ?)").bind(bayGio - 181 * NGAY, bayGio - NGAY),
      db.prepare("INSERT INTO idempotency_keys (pham_vi, khoa, bam_yeu_cau, trang_thai, tao_luc, het_han) VALUES ('p', 'k', 'h', 'xong', 0, ?)").bind(bayGio - 1),
    ]);
    const kq = (await (await post(`/thu/don-dep?bayGio=${bayGio}`, {}, ip(8))).json()) as { ipRutGon: number };
    expect(kq.ipRutGon).toBe(2);
    const ipD1 = await db.prepare("SELECT ip, count, ip_masked, first_seen, last_seen FROM device_ips WHERE device_id = 'd1' ORDER BY ip").all();
    expect(ipD1.results).toEqual([
      { ip: '10.1.2.0/24', count: 4, ip_masked: 1, first_seen: bayGio - 100 * NGAY - 5, last_seen: bayGio - 95 * NGAY },
      { ip: '10.9.9.9', count: 2, ip_masked: 0, first_seen: bayGio - 10 * NGAY - 5, last_seen: bayGio - 10 * NGAY },
    ]);
    expect((await db.prepare("SELECT ip FROM device_ips WHERE device_id = 'd2'").first<{ ip: string }>())?.ip).toBe('10.5.5.5');
    const sk = await db.prepare("SELECT id FROM security_events WHERE device_id = 'd1'").all<{ id: string }>();
    expect(sk.results.map((r) => r.id)).toEqual(['s-moi']);
    expect(await db.prepare("SELECT 1 FROM idempotency_keys WHERE pham_vi = 'p'").first()).toBeNull();
  });
});

describe('route thật', () => {
  it('/v1/health trong workerd + 404 problem', async () => {
    const h = await mf.dispatchFetch(`${goc}/v1/health`, { headers: ip(9) });
    expect(await h.json()).toEqual({ ok: true, moiTruong: 'test', build: 'local' });
    const k = await mf.dispatchFetch(`${goc}/khong-co`, { headers: ip(9) });
    expect(k.status).toBe(404);
  });
});
