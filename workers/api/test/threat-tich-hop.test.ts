// Mô phỏng lô sự kiện trên D1 + workerd thật (Miniflare) -> đúng điểm, trạng thái, enforcement, rule, chặn, đồng bộ Lists.
import type { D1Database } from '@cloudflare/workers-types';
import type { Miniflare } from 'miniflare';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { CAU_HINH_MAC_DINH } from '../src/thuan/nguy-co';
import { taoMf } from './tich-hop/mf';

let mf: Miniflare;
let db: D1Database;
const goc = 'https://compass-api.tsudev.com';
const GIO = 60 * 60 * 1000;
const NGAY = 24 * GIO;
let dem = 0;

const post = async <T = Record<string, unknown>>(duong: string, body: unknown): Promise<T> => {
  const res = await mf.dispatchFetch(`${goc}${duong}`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body) });
  if (!res.ok) throw new Error(`${duong} ${res.status} ${await res.text()}`);
  return (await res.json()) as T;
};
const id = () => crypto.randomUUID();
const sk = (type: string, them: Partial<{ id: string }> = {}) => ({ id: id(), type, severity: 'high', signals: {}, ...them });
type Kq = { nhan: number; trung: number; diem: number | null; trangThai: string | null; kichHoat: string[]; canDongBo: boolean };
const guiLo = (n: { thietBi: string | null; ip: string | null }, ds: unknown[], bayGio = Date.now()) => post<Kq>('/thu/su-kien', { n, ds, bayGio });

async function taoThietBi(ip: string, them: Record<string, unknown> = {}): Promise<string> {
  const tb = `dev-${++dem}`;
  const d = { model: 'Pixel 7', os_version: '14', build: 42, ...them };
  await db
    .prepare("INSERT INTO devices (id, installation_id_hash, platform, model, os_version, build, locale, country, first_seen, last_seen) VALUES (?, ?, 'android', ?, ?, ?, 'vi', 'VN', ?, ?)")
    .bind(tb, `h-${tb}`, d.model, d.os_version, d.build, Date.now() - NGAY, Date.now())
    .run();
  await db.prepare('INSERT INTO device_ips (device_id, ip, asn, country, first_seen, last_seen) VALUES (?, ?, 7552, ?, ?, ?)').bind(tb, ip, 'VN', Date.now(), Date.now()).run();
  await db.prepare('INSERT INTO sessions (id, device_id, issued_at, expires_at, refresh_hash) VALUES (?, ?, ?, ?, ?)').bind(id(), tb, 1, 2, id()).run();
  return tb;
}
const datLuat = async (ruleId: string, mode: 'active' | 'shadow') => {
  await db.prepare('UPDATE rules SET mode = ? WHERE id = ?').bind(mode, ruleId).run();
  await post('/thu/xoa-dem', {});
};
const datCauHinh = async (cfg: object) => {
  await db.prepare("INSERT INTO threat_config (version, config, created_by, created_at) VALUES ((SELECT coalesce(max(version), 0) + 1 FROM threat_config), ?, 'thu', 1)").bind(JSON.stringify(cfg)).run();
  await post('/thu/xoa-dem', {});
};
const thucThi = (giaTri: string) =>
  db.prepare('SELECT * FROM enforcements WHERE target_value = ? ORDER BY created_at').bind(giaTri).all<Record<string, unknown>>().then((r) => r.results);

beforeAll(async () => {
  mf = await taoMf();
  db = (await mf.getD1Database('DB')) as unknown as D1Database;
}, 60_000);
afterAll(async () => {
  await mf?.dispose();
});
beforeEach(async () => {
  await db.prepare("UPDATE rules SET mode = 'shadow'").run();
  await db.prepare('DELETE FROM threat_config').run();
  await post('/thu/xoa-dem', {});
});

describe('chấm điểm + trạng thái', () => {
  it('ATTEST_FAIL -> 60 restricted; gửi lại cùng event_id không cộng lần hai', async () => {
    const tb = await taoThietBi('203.0.113.10');
    const e = sk('ATTEST_FAIL');
    expect(await guiLo({ thietBi: tb, ip: '203.0.113.10' }, [e])).toMatchObject({ nhan: 1, trung: 0, diem: 60, trangThai: 'restricted' });
    expect(await guiLo({ thietBi: tb, ip: '203.0.113.10' }, [e])).toMatchObject({ nhan: 0, trung: 1, diem: 60 });
    const ev = await db.prepare('SELECT risk_delta, ip_prefix FROM security_events WHERE id = ?').bind(e.id).first();
    expect(ev).toEqual({ risk_delta: 60, ip_prefix: '203.0.113.0/24' });
  });

  it('>= 90 -> banned: enforcement ban 24h + audit, thu hồi phiên, DEVICE_BANNED, liên kết thiết bị giống', async () => {
    const giong = await taoThietBi('198.18.7.20');
    const tb = await taoThietBi('198.18.7.21');
    const bayGio = Date.now();
    const kq = await guiLo({ thietBi: tb, ip: '198.18.7.21' }, [sk('HOOK_FRIDA'), sk('APP_REPACKAGED')], bayGio);
    expect(kq).toMatchObject({ diem: 110, trangThai: 'banned' });
    const [e] = await thucThi(tb);
    expect(e).toMatchObject({ action: 'ban', source: 'auto', level: 0, reason: 'diem-nguy-co', expires_at: bayGio + NGAY, pending_approval: 0 });
    expect(await db.prepare('SELECT COUNT(*) AS n FROM sessions WHERE device_id = ? AND revoked_at IS NULL').bind(tb).first()).toEqual({ n: 0 });
    expect(await db.prepare("SELECT COUNT(*) AS n FROM security_events WHERE device_id = ? AND type = 'DEVICE_BANNED'").bind(tb).first()).toEqual({ n: 1 });
    expect(await db.prepare("SELECT COUNT(*) AS n FROM audit_logs WHERE action = 'enforcement.create' AND target = ?").bind(`device:${tb}`).first()).toEqual({ n: 1 });
    const lk = await db.prepare('SELECT linked_device_id, score FROM device_links WHERE device_id = ?').bind(tb).all();
    expect(lk.results).toEqual([{ linked_device_id: giong, score: 1 }]);
  });

  it('bị cấm lại sau khi hết hạn -> leo thang 7 ngày', async () => {
    const tb = await taoThietBi('198.18.8.1');
    const t0 = Date.now();
    await guiLo({ thietBi: tb, ip: '198.18.8.1' }, [sk('HOOK_FRIDA'), sk('HOOK_XPOSED')], t0);
    await guiLo({ thietBi: tb, ip: '198.18.8.1' }, [sk('HOOK_FRIDA')], t0 + 25 * GIO);
    const ds = await thucThi(tb);
    expect(ds.map((e) => [e.level, (e.expires_at as number) - (e.created_at as number)])).toEqual([[0, NGAY], [1, 7 * NGAY]]);
  });

  it('allow-list: lưu sự kiện điểm 0, không enforcement', async () => {
    const tb = await taoThietBi('192.0.2.50');
    await db.prepare("INSERT INTO allow_list (id, target_type, target_value, reason, created_by, created_at) VALUES (?, 'cidr', '192.0.2.0/24', 'store review', 'thu', 1)").bind(id()).run();
    await post('/thu/xoa-dem', {});
    expect(await guiLo({ thietBi: tb, ip: '192.0.2.50' }, [sk('ATTEST_FAIL'), sk('HOOK_FRIDA')])).toMatchObject({ nhan: 2, diem: 0, trangThai: 'clean' });
    expect(await thucThi(tb)).toEqual([]);
  });
});

describe('rule engine shadow / active', () => {
  it('R-003 shadow: ghi rule_hits + alert shadow, KHÔNG thực thi; active: +40 và restrict có TTL', async () => {
    await datCauHinh({ ...CAU_HINH_MAC_DINH, diem: { ...CAU_HINH_MAC_DINH.diem, SIGNATURE_MISMATCH: 1 } });
    const a = await taoThietBi('198.18.9.1');
    const ds5 = () => Array.from({ length: 5 }, () => sk('SIGNATURE_MISMATCH'));
    expect(await guiLo({ thietBi: a, ip: '198.18.9.1' }, ds5())).toMatchObject({ diem: 5, trangThai: 'clean', kichHoat: ['R-003'] });
    expect(await thucThi(a)).toEqual([]);
    expect(await db.prepare('SELECT shadow, actions FROM rule_hits WHERE group_key = ?').bind(`device:${a}`).first()).toEqual({
      shadow: 1,
      actions: '["add_risk_40","restrict_device"]',
    });
    // Cùng cửa sổ: không kích hoạt lại.
    expect((await guiLo({ thietBi: a, ip: '198.18.9.1' }, [sk('SIGNATURE_MISMATCH')])).kichHoat).toEqual([]);

    await datLuat('R-003', 'active');
    const b = await taoThietBi('198.18.9.2');
    expect(await guiLo({ thietBi: b, ip: '198.18.9.2' }, ds5())).toMatchObject({ diem: 45, trangThai: 'restricted', kichHoat: ['R-003'] });
    expect((await thucThi(b)).map((e) => [e.action, e.rule_id])).toEqual([['restrict', 'R-003']]);
  });

  it('R-004 đếm loại khác nhau: hook + gói lại -> ban_device + alert high', async () => {
    await datLuat('R-004', 'active');
    await datCauHinh({ ...CAU_HINH_MAC_DINH, diem: {} });
    const tb = await taoThietBi('198.18.10.1');
    expect(await guiLo({ thietBi: tb, ip: '198.18.10.1' }, [sk('HOOK_FRIDA'), sk('HOOK_FRIDA')])).toMatchObject({ trangThai: 'clean', kichHoat: [] });
    expect(await guiLo({ thietBi: tb, ip: '198.18.10.1' }, [sk('APP_REPACKAGED')])).toMatchObject({ diem: 0, trangThai: 'banned', kichHoat: ['R-004'] });
    expect(await db.prepare('SELECT severity, shadow, count FROM alerts WHERE rule_id = ? AND group_key = ?').bind('R-004', `device:${tb}`).first()).toEqual({
      severity: 'high',
      shadow: 0,
      count: 1,
    });
  });

  it('R-001 active: RATE_ABUSE lặp từ một IP -> chặn IP ở Worker (403 bi-chan) + cần đồng bộ Lists', async () => {
    await datLuat('R-001', 'active');
    const ipXau = '198.51.100.77';
    let kq: Kq | null = null;
    for (let i = 0; i < 3; i++) kq = await guiLo({ thietBi: null, ip: ipXau }, [sk('RATE_ABUSE')]);
    expect(kq).toMatchObject({ kichHoat: ['R-001'], canDongBo: true, diem: null });
    const res = await mf.dispatchFetch(`${goc}/v1/khong-co`, { headers: { 'cf-connecting-ip': ipXau } });
    expect(res.status).toBe(403);
    expect(await res.json()).toMatchObject({ status: 403, code: 'bi-chan' });
    const ok = await mf.dispatchFetch(`${goc}/v1/khong-co`, { headers: { 'cf-connecting-ip': '198.51.100.78' } });
    expect(ok.status).toBe(404);
  });

  it('R-002: 5 thiết bị bị cấm chung /24 -> chỉ ĐỀ XUẤT chặn dải (chờ duyệt, không chặn); Under Attack -> có hiệu lực', async () => {
    await datLuat('R-002', 'active');
    const dai = async (x: number, cfg?: object) => {
      if (cfg) await datCauHinh(cfg);
      for (let i = 1; i <= 5; i++) {
        const tb = await taoThietBi(`100.64.${x}.${i}`, { model: `M${x}-${i}` });
        await guiLo({ thietBi: tb, ip: `100.64.${x}.${i}` }, [sk('ATTEST_FAIL'), sk('HOOK_FRIDA')]);
      }
      return thucThi(`100.64.${x}.0/24`);
    };
    const [de] = await dai(1);
    expect(de).toMatchObject({ target_type: 'cidr', pending_approval: 1, action: 'block', rule_id: 'R-002' });
    expect((await mf.dispatchFetch(`${goc}/v1/khong-co`, { headers: { 'cf-connecting-ip': '100.64.1.200' } })).status).toBe(404);
    expect(await db.prepare("SELECT COUNT(*) AS n FROM audit_logs WHERE action = 'enforcement.propose'").first()).toEqual({ n: 1 });

    const [ua] = await dai(2, { ...CAU_HINH_MAC_DINH, underAttack: true });
    expect(ua).toMatchObject({ pending_approval: 0 });
    expect((await mf.dispatchFetch(`${goc}/v1/khong-co`, { headers: { 'cf-connecting-ip': '100.64.2.200' } })).status).toBe(403);
  });
});

describe('S8: bẫy quét + báo cáo CSP', () => {
  it('đường dẫn bẫy -> 404 như thường + sự kiện HONEYPOT_HIT theo IP (nhãn, không nguyên đường dẫn)', async () => {
    const ipQuet = '203.0.113.66';
    const res = await mf.dispatchFetch(`${goc}/.env.local?x=1`, { headers: { 'cf-connecting-ip': ipQuet } });
    expect(res.status).toBe(404);
    expect(await res.json()).toMatchObject({ status: 404 });
    let dong: { type: string; signals: string; device_id: string | null } | null = null;
    for (let i = 0; i < 50 && !dong; i++) {
      dong = await db.prepare('SELECT type, signals, device_id FROM security_events WHERE ip = ?').bind(ipQuet).first();
      if (!dong) await new Promise((r) => setTimeout(r, 20));
    }
    expect(dong).toEqual({ type: 'HONEYPOT_HIT', signals: JSON.stringify({ bay: '/.env', method: 'GET' }), device_id: null });
  });
  it('R-006 active: chạm bẫy lặp lại -> chặn IP', async () => {
    await datLuat('R-006', 'active');
    const ipQuet = '203.0.113.67';
    let kq: Kq | null = null;
    for (let i = 0; i < 3; i++) kq = await guiLo({ thietBi: null, ip: ipQuet }, [sk('HONEYPOT_HIT')]);
    expect(kq).toMatchObject({ kichHoat: ['R-006'], canDongBo: true });
    const res = await mf.dispatchFetch(`${goc}/v1/khong-co`, { headers: { 'cf-connecting-ip': ipQuet } });
    expect(res.status).toBe(403);
    await datLuat('R-006', 'shadow');
  });
  it('POST /v1/web/csp: 204, sai loại 415, preflight chỉ cho origin web', async () => {
    const gui = (ct: string, body: string) =>
      mf.dispatchFetch(`${goc}/v1/web/csp`, { method: 'POST', headers: { 'content-type': ct, 'cf-connecting-ip': '198.51.100.90' }, body });
    const bc = JSON.stringify({ 'csp-report': { 'document-uri': 'https://compass.tsudev.com/', 'effective-directive': 'script-src-elem', 'blocked-uri': 'inline' } });
    expect((await gui('application/csp-report', bc)).status).toBe(204);
    expect((await gui('application/reports+json', '[]')).status).toBe(204);
    expect((await gui('text/plain', bc)).status).toBe(415);
    const pf = (origin: string) =>
      mf.dispatchFetch(`${goc}/v1/web/csp`, {
        method: 'OPTIONS',
        headers: { origin, 'access-control-request-method': 'POST', 'access-control-request-headers': 'content-type' },
      });
    expect((await pf('https://compass.tsudev.com')).headers.get('access-control-allow-origin')).toBe('https://compass.tsudev.com');
    expect((await pf('https://evil.example')).headers.get('access-control-allow-origin')).toBeNull();
  });
});

describe('cron Threat Engine', () => {
  it('enforcement hết hạn -> hạ trạng thái theo điểm; đủ tuần không vi phạm -> trừ 5/tuần', async () => {
    const tb = await taoThietBi('198.18.11.1');
    const t0 = Date.now();
    await guiLo({ thietBi: tb, ip: '198.18.11.1' }, [sk('HOOK_FRIDA'), sk('HOOK_XPOSED')], t0);
    await post('/thu/dinh-ky', {});
    const sau = (bayGio: number) => post<{ xet: number; doi: number }>(`/thu/dinh-ky?bayGio=${bayGio}`, {});
    await sau(t0 + 2 * GIO);
    expect(await db.prepare('SELECT status, risk_score FROM devices WHERE id = ?').bind(tb).first()).toEqual({ status: 'banned', risk_score: 100 });
    await sau(t0 + 15 * NGAY);
    expect(await db.prepare('SELECT status, risk_score FROM devices WHERE id = ?').bind(tb).first()).toEqual({ status: 'banned', risk_score: 90 });
    await sau(t0 + 22 * NGAY);
    expect(await db.prepare('SELECT status, risk_score FROM devices WHERE id = ?').bind(tb).first()).toEqual({ status: 'restricted', risk_score: 85 });
  });
});

describe('đồng bộ Cloudflare Lists', () => {
  it('thêm IP đang chặn, xoá item của engine đã hết hạn, giữ item thủ công', async () => {
    const bayGio = Date.now();
    const kq = await post<{ kq: { them: number; xoa: number }; goi: { method: string; body: unknown }[] }>('/thu/dong-bo', {
      bayGio,
      hienCo: [
        { id: 'cu', ip: '9.9.9.9', comment: 'la-ban:prod:E-cu' },
        { id: 'tay', ip: '8.8.8.8', comment: 'tay' },
      ],
    });
    expect(kq.goi.map((g) => g.method)).toEqual(['GET', 'POST', 'DELETE']);
    const them = kq.goi[1]?.body as { ip: string; comment: string }[];
    expect(them.map((t) => t.ip)).toEqual(expect.arrayContaining(['198.51.100.77', '100.64.2.0/24']));
    expect(them.map((t) => t.ip)).not.toContain('100.64.1.0/24');
    expect(kq.goi[2]?.body).toEqual({ items: [{ id: 'cu' }] });
  });
});
