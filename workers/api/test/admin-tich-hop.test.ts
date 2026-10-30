// Admin SOC (S6) trên workerd thật: Access JWT -> vai trò -> passkey -> phiên -> quyền / che PII -> realtime WebSocket.
import type { D1Database } from '@cloudflare/workers-types';
import type { Miniflare } from 'miniflare';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { AccessGia, PasskeyGia } from './tich-hop/soc-gia';
import { taoMf } from './tich-hop/mf';

const NGUON = 'https://soc.test';
const GOC = 'https://compass-api.tsudev.com/admin/v1';
let mf: Miniflare;
let db: D1Database;
let access: AccessGia;
const tinTelegram: { chat_id: string; text: string }[] = [];

type Kq = { status: number; json: Record<string, unknown>; cookie: string | null };

async function goi(duong: string, p: { jwt?: string; cookie?: string | null; body?: unknown; origin?: string; xSoc?: boolean; nen?: boolean } = {}): Promise<Kq> {
  const h: Record<string, string> = {};
  if (p.jwt) h['cf-access-jwt-assertion'] = p.jwt;
  if (p.cookie) h.cookie = p.cookie;
  if (p.nen) h['x-soc-nen'] = '1';
  if (p.body !== undefined) {
    h['content-type'] = 'application/json';
    h.origin = p.origin ?? NGUON;
    if (p.xSoc !== false) h['x-soc'] = '1';
  }
  const res = await mf.dispatchFetch(
    `${GOC}${duong}`,
    p.body === undefined ? { headers: h } : { method: 'POST', headers: h, body: JSON.stringify(p.body) },
  );
  const setCookie = res.headers.get('set-cookie');
  return { status: res.status, json: (await res.json().catch(() => ({}))) as Record<string, unknown>, cookie: setCookie ? setCookie.split(';')[0] ?? null : null };
}

async function themQt(email: string, role: string) {
  await db.prepare('INSERT INTO admin_users (id, email, role) VALUES (?, ?, ?)').bind(crypto.randomUUID(), email, role).run();
}

/** Đăng ký passkey đầu tiên -> cookie phiên. */
async function vaoSoc(email: string): Promise<{ jwt: string; cookie: string; pk: PasskeyGia }> {
  const jwt = await access.jwt({ email });
  const pk = await PasskeyGia.tao();
  const bd = await goi('/passkey/dang-ky/bat-dau', { jwt, body: {} });
  expect(bd.status).toBe(200);
  const tc = bd.json.tuyChon as { challenge: string; rp: { id: string } };
  expect(tc.rp.id).toBe('soc.test');
  const xong = await goi('/passkey/dang-ky/xong', { jwt, body: { thachThucId: bd.json.thachThucId, ...(await pk.dangKy(tc, NGUON)) } });
  expect(xong.status).toBe(201);
  expect(xong.cookie).toMatch(/^__Host-soc=/);
  return { jwt, cookie: xong.cookie as string, pk };
}

async function dangNhap(jwt: string, pk: PasskeyGia, cookie: string | null = null): Promise<Kq> {
  const bd = await goi('/phien/bat-dau', { jwt, cookie, body: {} });
  expect(bd.status).toBe(200);
  return goi('/phien/xong', { jwt, cookie, body: { thachThucId: bd.json.thachThucId, ...(await pk.xacThuc(bd.json.tuyChon as { challenge: string; rpId: string }, NGUON)) } });
}

beforeAll(async () => {
  access = await AccessGia.tao();
  mf = await taoMf(undefined, {
    bindings: {
      ACCESS_TEAM: access.team,
      ACCESS_AUD: `khac,${access.aud}`,
      SOC_NGUON: NGUON,
      ACCESS_DICH_VU: 'svc-thu.access',
      TELEGRAM_BOT_TOKEN: '1:thu',
      TELEGRAM_CHAT_ID: '-100',
    },
    outboundService: async (req) => {
      const u = new URL(req.url);
      if (u.hostname === 'api.telegram.org') {
        tinTelegram.push((await req.json()) as { chat_id: string; text: string });
        return Response.json({ ok: true });
      }
      return u.pathname === '/cdn-cgi/access/certs' ? access.jwks() : new Response('x', { status: 404 });
    },
  });
  db = (await mf.getD1Database('DB')) as unknown as D1Database;
  await db
    .prepare("INSERT INTO devices (id, installation_id_hash, platform, model, os_version, app_version, build, country, first_seen, last_seen) VALUES ('01JTB0000000000000000000AA', 'h1', 'android', 'Galaxy M32', '13', '0.1.0', 7, 'VN', 1, ?)")
    .bind(Date.now())
    .run();
  await db.prepare("INSERT INTO device_ips (device_id, ip, asn, country, first_seen, last_seen) VALUES ('01JTB0000000000000000000AA', '203.0.113.77', 7552, 'VN', 1, ?)").bind(Date.now()).run();
  await themQt('viewer@thu.vn', 'viewer');
  await themQt('analyst@thu.vn', 'analyst');
  await themQt('sa@thu.vn', 'super_admin');
}, 60_000);
afterAll(async () => {
  await mf?.dispose();
});

describe('lớp Access + vai trò', () => {
  it('thiếu / sai JWT -> 401; JWT đúng nhưng không có vai trò -> 403', async () => {
    expect((await goi('/toi')).status).toBe(401);
    expect((await goi('/toi', { jwt: await access.jwt({ email: 'viewer@thu.vn', aud: ['aud-khac'] }) })).status).toBe(401);
    expect((await goi('/toi', { jwt: await access.jwt({ email: 'viewer@thu.vn', exp: 1 }) })).status).toBe(401);
    const gia = await access.jwt({ email: 'viewer@thu.vn' });
    expect((await goi('/toi', { jwt: `${gia.slice(0, -4)}AAAA` })).status).toBe(401);
    const r = await goi('/toi', { jwt: await access.jwt({ email: 'nguoi-la@thu.vn' }) });
    expect(r.status).toBe(403);
    expect(r.json.code).toBe('khong-co-vai-tro');
  });

  it('service token chỉ nhận khi có trong ACCESS_DICH_VU và có vai trò', async () => {
    expect((await goi('/toi', { jwt: await access.jwt({ common_name: 'svc-la.access' }) })).status).toBe(401);
    expect((await goi('/toi', { jwt: await access.jwt({ common_name: 'svc-thu.access' }) })).status).toBe(403);
    await themQt('svc:svc-thu.access', 'viewer');
    const r = await goi('/toi', { jwt: await access.jwt({ common_name: 'svc-thu.access' }) });
    expect(r.status).toBe(200);
    expect(r.json.email).toBe('svc:svc-thu.access');
  });

  it('có vai trò nhưng chưa có phiên passkey -> dữ liệu 401 can-phien', async () => {
    const jwt = await access.jwt({ email: 'Viewer@Thu.vn' });
    const toi = await goi('/toi', { jwt });
    expect(toi.json).toMatchObject({ email: 'viewer@thu.vn', vaiTro: 'viewer', soPasskey: 0, phien: null });
    const r = await goi('/tong-quan', { jwt });
    expect(r.status).toBe(401);
    expect(r.json.code).toBe('can-phien');
  });

  it('chống CSRF: thiếu x-soc / sai Origin -> 403', async () => {
    const jwt = await access.jwt({ email: 'viewer@thu.vn' });
    expect((await goi('/phien/bat-dau', { jwt, body: {}, xSoc: false })).status).toBe(403);
    expect((await goi('/phien/bat-dau', { jwt, body: {}, origin: 'https://evil.test' })).status).toBe(403);
  });
});

describe('passkey + phiên', () => {
  it('viewer: đăng ký passkey -> phiên; danh sách che IP; chi tiết bị cấm', async () => {
    const { jwt, cookie } = await vaoSoc('viewer@thu.vn');
    const tq = await goi('/tong-quan', { jwt, cookie });
    expect(tq.status).toBe(200);
    expect((tq.json.thietBi as { tong: number }).tong).toBe(1);
    const ds = await goi('/thiet-bi', { jwt, cookie });
    expect(ds.status).toBe(200);
    expect((ds.json.ds as { ip: string }[])[0]?.ip).toBe('203.0.113.0/24');
    expect((await goi('/thiet-bi/01JTB0000000000000000000AA', { jwt, cookie })).status).toBe(403);
    expect((await goi('/quan-tri-vien', { jwt, cookie })).status).toBe(403);
    // Cookie của viewer + JWT người khác -> không dùng được.
    expect((await goi('/tong-quan', { jwt: await access.jwt({ email: 'analyst@thu.vn' }), cookie })).status).toBe(401);
  });

  it('analyst: đăng nhập bằng passkey, thấy IP đầy đủ + chi tiết, xem chi tiết có audit', async () => {
    const { jwt, pk } = await vaoSoc('analyst@thu.vn');
    const dn = await dangNhap(jwt, pk);
    expect(dn.status).toBe(200);
    const cookie = dn.cookie as string;
    const ds = await goi('/thiet-bi?ip=203.0.113.0/24&trangThai=clean', { jwt, cookie });
    expect((ds.json.ds as { ip: string }[])[0]?.ip).toBe('203.0.113.77');
    const ct = await goi('/thiet-bi/01JTB0000000000000000000AA', { jwt, cookie });
    expect(ct.status).toBe(200);
    expect((ct.json.ips as unknown[]).length).toBe(1);
    await new Promise((r) => setTimeout(r, 100));
    const audit = await db.prepare("SELECT actor FROM audit_logs WHERE action = 'xem:thiet-bi'").all<{ actor: string }>();
    expect(audit.results.map((a) => a.actor)).toContain('analyst@thu.vn');
    expect((await goi('/thiet-bi?ip=khong-phai-ip', { jwt, cookie })).status).toBe(400);
    expect((await goi('/thiet-bi?la=1', { jwt, cookie })).status).toBe(400);
  });

  it('thách thức dùng một lần; bộ đếm passkey tụt -> từ chối', async () => {
    const { jwt, pk } = await vaoSoc('sa@thu.vn');
    const bd = await goi('/phien/bat-dau', { jwt, body: {} });
    const phanHoi = await pk.xacThuc(bd.json.tuyChon as { challenge: string; rpId: string }, NGUON);
    expect((await goi('/phien/xong', { jwt, body: { thachThucId: bd.json.thachThucId, ...phanHoi } })).status).toBe(200);
    expect((await goi('/phien/xong', { jwt, body: { thachThucId: bd.json.thachThucId, ...phanHoi } })).status).toBe(400);
    pk.dem -= 1;
    const lui = await dangNhap(jwt, pk).catch(() => null);
    expect(lui?.status).toBe(400);
  });

  it('đăng xuất: thu hồi phiên + xoá cookie', async () => {
    await themQt('v1@thu.vn', 'viewer');
    const { jwt, cookie } = await vaoSoc('v1@thu.vn');
    const kx = await goi('/phien/ket-thuc', { jwt, cookie, body: {} });
    expect(kx.status).toBe(200);
    expect(kx.cookie).toBe('__Host-soc=');
    expect((await goi('/tong-quan', { jwt, cookie })).status).toBe(401);
  });
});

describe('quản trị viên (super admin, step-up)', () => {
  it('thêm passkey thứ hai cần phiên + step-up', async () => {
    const jwt = await access.jwt({ email: 'sa@thu.vn' });
    expect((await goi('/passkey/dang-ky/bat-dau', { jwt, body: {} })).status).toBe(401);
  });

  it('step-up quá 5 phút -> 401; tự sửa mình -> 409; vô hiệu người khác -> người đó 403 + mất phiên', async () => {
    await themQt('sa2@thu.vn', 'super_admin');
    const { jwt, cookie } = await vaoSoc('sa2@thu.vn');
    const ds = await goi('/quan-tri-vien', { jwt, cookie });
    expect(ds.status).toBe(200);
    await db.prepare("UPDATE admin_sessions SET step_up_at = ? WHERE email = 'sa2@thu.vn'").bind(Date.now() - 6 * 60_000).run();
    const can = await goi('/quan-tri-vien', { jwt, cookie, body: { email: 'moi@thu.vn', vaiTro: 'analyst' } });
    expect(can.status).toBe(401);
    expect(can.json.code).toBe('can-step-up');
    await db.prepare("UPDATE admin_sessions SET step_up_at = ? WHERE email = 'sa2@thu.vn'").bind(Date.now()).run();
    expect((await goi('/quan-tri-vien', { jwt, cookie, body: { email: 'moi@thu.vn', vaiTro: 'analyst' } })).status).toBe(201);
    expect((await goi('/quan-tri-vien', { jwt, cookie, body: { email: 'sa2@thu.vn', vaiTro: 'viewer' } })).status).toBe(409);
    expect((await goi('/quan-tri-vien', { jwt, cookie, body: { email: 'analyst@thu.vn', vaiTro: 'analyst', voHieu: true } })).status).toBe(200);
    expect((await goi('/toi', { jwt: await access.jwt({ email: 'analyst@thu.vn' }) })).status).toBe(403);
    const mo = await db.prepare("SELECT COUNT(*) AS n FROM admin_sessions WHERE email = 'analyst@thu.vn' AND revoked_at IS NULL").first<{ n: number }>();
    expect(mo?.n).toBe(0);
    const a = await db.prepare("SELECT action FROM audit_logs WHERE actor = 'sa2@thu.vn' ORDER BY rowid").all<{ action: string }>();
    expect(a.results.map((x) => x.action)).toEqual(['passkey:dang-ky', 'quan-tri-vien:them', 'quan-tri-vien:sua']);
  });

  it('phiên nhàn rỗi > 15 phút bị từ chối; request nền không gia hạn', async () => {
    await themQt('v2@thu.vn', 'viewer');
    const { jwt, cookie } = await vaoSoc('v2@thu.vn');
    const gan = Date.now() - 14 * 60_000;
    await db.prepare("UPDATE admin_sessions SET last_active = ? WHERE email = 'v2@thu.vn'").bind(gan).run();
    expect((await goi('/tong-quan', { jwt, cookie, nen: true })).status).toBe(200);
    const sau = await db.prepare("SELECT last_active FROM admin_sessions WHERE email = 'v2@thu.vn'").first<{ last_active: number }>();
    expect(sau?.last_active).toBe(gan);
    await db.prepare("UPDATE admin_sessions SET last_active = ? WHERE email = 'v2@thu.vn'").bind(Date.now() - 16 * 60_000).run();
    expect((await goi('/tong-quan', { jwt, cookie })).status).toBe(401);
  });
});

describe('realtime', () => {
  it('sự kiện mới tới WebSocket SOC < 1,5 s, viewer nhận IP rút gọn', async () => {
    await themQt('v3@thu.vn', 'viewer');
    const { jwt, cookie } = await vaoSoc('v3@thu.vn');
    const res = await mf.dispatchFetch(`${GOC}/ws`, { headers: { upgrade: 'websocket', origin: NGUON, 'cf-access-jwt-assertion': jwt, cookie } });
    expect(res.status).toBe(101);
    const ws = res.webSocket;
    if (!ws) throw new Error('không có webSocket');
    ws.accept();
    const tin = new Promise<{ nhanLuc: number; ip: string; ds: { type: string }[] }>((xong) => {
      ws.addEventListener('message', (e) => xong(JSON.parse(String(e.data))));
    });
    const gui = Date.now();
    const r = await mf.dispatchFetch('https://compass-api.tsudev.com/thu/su-kien', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        n: { thietBi: '01JTB0000000000000000000AA', ip: '203.0.113.77' },
        ds: [{ id: crypto.randomUUID(), type: 'ROOT_DETECTED', severity: 'high', signals: {} }],
      }),
    });
    expect(r.status).toBe(200);
    const t = await tin;
    expect(Date.now() - gui).toBeLessThan(1500);
    expect(t.ip).toBe('203.0.113.0/24');
    expect(t.ds[0]?.type).toBe('ROOT_DETECTED');
    ws.close();
    // Thiếu Origin đúng -> không nâng cấp được.
    const sai = await mf.dispatchFetch(`${GOC}/ws`, { headers: { upgrade: 'websocket', origin: 'https://evil.test', 'cf-access-jwt-assertion': jwt, cookie } });
    expect(sai.status).toBe(403);
  });
});

describe('trung tâm cảnh báo (S7a)', () => {
  const TB = '01JTB0000000000000000000AA';
  const guiSuKien = (type: string) =>
    mf.dispatchFetch('https://compass-api.tsudev.com/thu/su-kien', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ n: { thietBi: TB, ip: '203.0.113.77' }, ds: [{ id: crypto.randomUUID(), type, severity: 'high', signals: {} }] }),
    });

  it('alert thật mức cao -> Telegram MỘT lần, không lộ device id / IP đầy đủ; ack rồi kích hoạt lại -> gộp vào dòng cũ', async () => {
    await db.prepare("UPDATE rules SET mode = 'active' WHERE id = 'R-004'").run();
    await mf.dispatchFetch('https://compass-api.tsudev.com/thu/xoa-dem', { method: 'POST', headers: { 'content-type': 'application/json' }, body: '{}' });
    expect((await guiSuKien('HOOK_FRIDA')).status).toBe(200);
    expect((await guiSuKien('APP_REPACKAGED')).status).toBe(200);
    const a = await db.prepare("SELECT id, status, count, notified_at FROM alerts WHERE rule_id = 'R-004'").all<{ id: string; status: string; count: number; notified_at: number | null }>();
    expect(a.results).toHaveLength(1);
    expect(a.results[0]?.notified_at).toBeGreaterThan(0);
    expect(tinTelegram).toHaveLength(1);
    expect(tinTelegram[0]?.chat_id).toBe('-100');
    expect(tinTelegram[0]?.text).toContain('R-004');
    expect(tinTelegram[0]?.text).toContain(`device:${TB.slice(0, 8)}`);
    expect(tinTelegram[0]?.text).not.toContain(TB);

    await themQt('an1@thu.vn', 'analyst');
    const { jwt, cookie } = await vaoSoc('an1@thu.vn');
    const id = a.results[0]?.id as string;
    expect((await goi('/canh-bao/thao-tac', { jwt, cookie, body: { ids: [id], hanhDong: 'nhan' } })).json).toEqual({ capNhat: 1, boQua: 0 });
    await db.prepare("DELETE FROM rule_hits WHERE rule_id = 'R-004'").run();
    expect((await guiSuKien('HOOK_XPOSED')).status).toBe(200);
    const sau = await db.prepare("SELECT status, count, assignee FROM alerts WHERE rule_id = 'R-004'").all();
    expect(sau.results).toEqual([{ status: 'ack', count: 2, assignee: 'an1@thu.vn' }]);
    expect(tinTelegram).toHaveLength(1);
  });

  it('lọc + thao tác: viewer chỉ xem (IP che), analyst đóng cần kết luận, mở lại, phân công hợp lệ, dòng thời gian + audit', async () => {
    const bayGio = Date.now();
    await db.batch([
      db.prepare("INSERT INTO alerts (id, rule_id, severity, group_key, first_ts, last_ts) VALUES ('01JALERT00000000000000000A', 'R-001', 'medium', 'ip:198.51.100.9', ?, ?)").bind(bayGio, bayGio),
      db.prepare("INSERT INTO alerts (id, rule_id, severity, group_key, shadow, first_ts, last_ts) VALUES ('01JALERT00000000000000000B', 'R-003', 'low', 'cidr24:198.51.100.0/24', 1, ?, ?)").bind(bayGio - 1, bayGio - 1),
    ]);
    await themQt('v9@thu.vn', 'viewer');
    const v = await vaoSoc('v9@thu.vn');
    const dsV = await goi('/canh-bao?rule=R-001', { jwt: v.jwt, cookie: v.cookie });
    expect(dsV.status).toBe(200);
    expect((dsV.json.ds as { group_key: string }[])[0]?.group_key).toBe('ip:198.51.100.0/24');
    expect((await goi('/canh-bao/thao-tac', { jwt: v.jwt, cookie: v.cookie, body: { ids: ['01JALERT00000000000000000A'], hanhDong: 'ack' } })).status).toBe(403);

    await themQt('an2@thu.vn', 'analyst');
    const { jwt, cookie } = await vaoSoc('an2@thu.vn');
    const ds = await goi('/canh-bao?shadow=an&q=198.51', { jwt, cookie });
    expect((ds.json.ds as { id: string; group_key: string }[]).map((x) => [x.id, x.group_key])).toEqual([['01JALERT00000000000000000A', 'ip:198.51.100.9']]);
    expect((await goi('/canh-bao?trangThai=sai', { jwt, cookie })).status).toBe(400);
    const ids = ['01JALERT00000000000000000A', '01JALERT00000000000000000B'];
    expect((await goi('/canh-bao/thao-tac', { jwt, cookie, body: { ids, hanhDong: 'dong' } })).status).toBe(422);
    expect((await goi('/canh-bao/thao-tac', { jwt, cookie, body: { ids, hanhDong: 'phan-cong', nguoi: 'v9@thu.vn' } })).json.code).toBe('nguoi-xu-ly-loi');
    expect((await goi('/canh-bao/thao-tac', { jwt, cookie, body: { ids, hanhDong: 'phan-cong', nguoi: 'an1@thu.vn' } })).json).toEqual({ capNhat: 2, boQua: 0 });
    expect((await goi('/canh-bao?nguoi=an1@thu.vn&trangThai=tat-ca', { jwt, cookie })).json.dem).toMatchObject({ mo: expect.any(Number) });
    expect((await goi('/canh-bao/thao-tac', { jwt, cookie, body: { ids, hanhDong: 'dong', ketLuan: 'false_positive', ghiChu: 'IP văn phòng' } })).json).toEqual({ capNhat: 2, boQua: 0 });
    expect((await goi('/canh-bao/thao-tac', { jwt, cookie, body: { ids, hanhDong: 'ack' } })).json).toEqual({ capNhat: 0, boQua: 2 });
    expect((await goi('/canh-bao/thao-tac', { jwt, cookie, body: { ids: [ids[0]], hanhDong: 'mo-lai' } })).json).toEqual({ capNhat: 1, boQua: 0 });

    const ct = await goi(`/canh-bao/${ids[0]}`, { jwt, cookie });
    expect(ct.status).toBe(200);
    expect(ct.json.canhBao).toMatchObject({ status: 'open', resolution: null, assignee: 'an1@thu.vn' });
    expect(ct.json.dich).toEqual({ loai: 'ip', giaTri: '198.51.100.9' });
    expect((ct.json.dongThoiGian as { kind: string; body: string }[]).map((g) => g.kind).sort()).toEqual(['assign', 'note', 'status', 'status']);
    const audit = await db.prepare("SELECT action, target FROM audit_logs WHERE actor = 'an2@thu.vn' AND action LIKE 'canh-bao:%' ORDER BY rowid").all();
    expect(audit.results).toEqual([
      { action: 'canh-bao:phan-cong', target: 'alerts:2' },
      { action: 'canh-bao:dong', target: 'alerts:2' },
      { action: 'canh-bao:mo-lai', target: `alert:${ids[0]}` },
    ]);
    expect((await goi('/canh-bao/nguoi-xu-ly', { jwt, cookie })).json.ds).toContain('an1@thu.vn');
  });

  it('passkey: xem, đổi tên, xoá cần step-up, không xoá passkey cuối', async () => {
    await themQt('pk@thu.vn', 'viewer');
    const { jwt, cookie } = await vaoSoc('pk@thu.vn');
    const ds = await goi('/passkey', { jwt, cookie });
    const pk = (ds.json.ds as { id: string }[])[0] as { id: string };
    expect((await goi('/passkey/doi-ten', { jwt, cookie, body: { id: pk.id, ten: 'Laptop' } })).status).toBe(200);
    expect((await goi('/passkey', { jwt, cookie })).json.ds).toMatchObject([{ name: 'Laptop' }]);
    expect((await goi('/passkey/xoa', { jwt, cookie, body: { id: pk.id } })).json.code).toBe('passkey-cuoi');
    await db.prepare("UPDATE admin_sessions SET step_up_at = ? WHERE email = 'pk@thu.vn'").bind(Date.now() - 6 * 60_000).run();
    expect((await goi('/passkey/xoa', { jwt, cookie, body: { id: pk.id } })).json.code).toBe('can-step-up');
    expect((await goi('/passkey/doi-ten', { jwt, cookie, body: { id: 'khong-co-khoa-nay-0000', ten: 'x' } })).status).toBe(404);
  });
});

describe('S7b: rule + can thiệp + four-eyes + cài đặt SOC', () => {
  const TB = '01JTB0000000000000000000AA';
  const TB2 = '01JTB0000000000000000000S7';

  it('rule: analyst xem + mô phỏng, không sửa; security_admin sửa -> phiên bản mới + về shadow; active trước 7 ngày bị chặn', async () => {
    await themQt('an7@thu.vn', 'analyst');
    const an = await vaoSoc('an7@thu.vn');
    const ds = await goi('/luat', { jwt: an.jwt, cookie: an.cookie });
    expect(ds.status).toBe(200);
    const r3 = (ds.json.ds as { id: string; phienBan: number; cheDo: string; coTheBat: boolean }[]).find((x) => x.id === 'R-003');
    expect(r3).toMatchObject({ phienBan: 1, cheDo: 'shadow' });

    const bayGio = Date.now();
    await db.batch(
      [0, 1, 2].map((i) =>
        db
          .prepare("INSERT INTO security_events (id, device_id, type, severity, signals, ip, ip_prefix, ts, risk_delta) VALUES (?, ?, 'SIGNATURE_MISMATCH', 'high', '{}', '203.0.113.77', '203.0.113.0/24', ?, 0)")
          .bind(crypto.randomUUID(), TB, bayGio - 60_000 + i),
      ),
    );
    const than = { ten: 'Sai chữ ký liên tiếp', dieuKien: { event: ['SIGNATURE_MISMATCH'], group_by: 'device', count: 'events' }, cuaSo: 600, nguong: 3, hanhDong: ['add_risk_40', 'restrict_device'] };
    const mp = await goi('/luat/mo-phong', { jwt: an.jwt, cookie: an.cookie, body: { id: 'R-003', than } });
    expect(mp.status).toBe(200);
    expect(mp.json).toMatchObject({ soLanKichHoat: 1, soNhom: 1, catBot: false, topNhom: [{ khoa: `device:${TB}`, n: 1 }] });
    expect((await goi('/luat/mo-phong', { jwt: an.jwt, cookie: an.cookie, body: { than: { ...than, nguong: 4 } } })).json.soLanKichHoat).toBe(0);
    const sua = { id: 'R-003', phienBan: 1, than: { ...than, nguong: 4 }, ghiChu: 'Giảm báo động giả' };
    expect((await goi('/luat/sua', { jwt: an.jwt, cookie: an.cookie, body: sua })).status).toBe(403);

    await themQt('sec@thu.vn', 'security_admin');
    const sec = await vaoSoc('sec@thu.vn');
    await db.prepare("UPDATE rules SET mode = 'active' WHERE id = 'R-003'").run();
    const kq = await goi('/luat/sua', { jwt: sec.jwt, cookie: sec.cookie, body: sua });
    expect(kq.json).toEqual({ ok: true, phienBan: 2, veShadow: true });
    expect((await goi('/luat/sua', { jwt: sec.jwt, cookie: sec.cookie, body: sua })).json.code).toBe('phien-ban-cu');
    const ct = await goi('/luat/R-003', { jwt: an.jwt, cookie: an.cookie });
    expect(ct.json.luat).toMatchObject({ phienBan: 2, nguong: 4, cheDo: 'shadow', coTheBat: false });
    expect((ct.json.phienBan as { version: number; note: string }[]).map((p) => [p.version, p.note])).toEqual([[2, 'Giảm báo động giả'], [1, 'ban dau']]);
    const bat = await goi('/luat/che-do', { jwt: sec.jwt, cookie: sec.cookie, body: { id: 'R-003', phienBan: 2, cheDo: 'active', ghiChu: 'Bật thực thi thử' } });
    expect(bat.json.code).toBe('chua-du-shadow');
    await db.prepare('UPDATE rules SET shadow_since = ? WHERE id = ?').bind(Date.now() - 8 * 24 * 3600_000, 'R-003').run();
    expect((await goi('/luat/che-do', { jwt: sec.jwt, cookie: sec.cookie, body: { id: 'R-003', phienBan: 2, cheDo: 'active', ghiChu: 'Đủ 7 ngày shadow' } })).json).toEqual({ ok: true });
    const audit = await db.prepare("SELECT action FROM audit_logs WHERE actor = 'sec@thu.vn' AND action LIKE 'luat:%' ORDER BY rowid").all();
    expect(audit.results).toEqual([{ action: 'luat:sua' }, { action: 'luat:che-do' }]);
  });

  it('Under Attack + cấu hình điểm: phiên bản mới, sai schema 400, cần step-up', async () => {
    await themQt('sec3@thu.vn', 'security_admin');
    const s = await vaoSoc('sec3@thu.vn');
    expect((await goi('/under-attack', { jwt: s.jwt, cookie: s.cookie, body: { bat: true, ghiChu: 'Bị quét diện rộng' } })).json).toEqual({ ok: true, phienBan: 1 });
    const ch = await goi('/cau-hinh-nguy-co', { jwt: s.jwt, cookie: s.cookie });
    expect(ch.json).toMatchObject({ phienBan: 1, cauHinh: { underAttack: true } });
    const cfg = { ...(ch.json.cauHinh as Record<string, unknown>), underAttack: false, nguong: { suspicious: 90, restricted: 60, banned: 30 } };
    expect((await goi('/cau-hinh-nguy-co', { jwt: s.jwt, cookie: s.cookie, body: { phienBan: 1, cauHinh: cfg, ghiChu: 'Thử ngưỡng sai' } })).json.code).toBe('cau-hinh-loi');
    expect((await goi('/cau-hinh-nguy-co', { jwt: s.jwt, cookie: s.cookie, body: { phienBan: 0, cauHinh: { ...cfg, nguong: { suspicious: 30, restricted: 60, banned: 90 } }, ghiChu: 'Bản cũ ghi đè' } })).json.code).toBe('phien-ban-cu');
    await db.prepare("UPDATE admin_sessions SET step_up_at = ? WHERE email = 'sec3@thu.vn'").bind(Date.now() - 6 * 60_000).run();
    expect((await goi('/under-attack', { jwt: s.jwt, cookie: s.cookie, body: { bat: false, ghiChu: 'Hết đợt tấn công' } })).json.code).toBe('can-step-up');
    await db.prepare("UPDATE admin_sessions SET step_up_at = ? WHERE email = 'sec3@thu.vn'").bind(Date.now()).run();
    expect((await goi('/under-attack', { jwt: s.jwt, cookie: s.cookie, body: { bat: false, ghiChu: 'Hết đợt tấn công' } })).json).toEqual({ ok: true, phienBan: 2 });
  });

  it('can thiệp: cấm thiết bị -> banned + thu hồi phiên; gỡ -> hạ trạng thái; dải -> đề xuất, người tạo không tự duyệt', async () => {
    const bayGio = Date.now();
    await db
      .prepare("INSERT INTO devices (id, installation_id_hash, platform, first_seen, last_seen) VALUES (?, 'h-s7b', 'android', 1, ?)")
      .bind(TB2, bayGio)
      .run();
    await db.prepare("INSERT INTO sessions (id, device_id, issued_at, expires_at, refresh_hash) VALUES ('p-s7b', ?, ?, ?, 'rh-s7b')").bind(TB2, bayGio, bayGio + 3600_000).run();
    await themQt('re@thu.vn', 'responder');
    const re = await vaoSoc('re@thu.vn');
    const thieuLyDo = await goi('/thuc-thi/chan', { jwt: re.jwt, cookie: re.cookie, body: { dich: [{ loai: 'device', giaTri: TB2 }], hanhDong: 'ban', thoiHan: '24h', lyDo: 'ngắn' } });
    expect(thieuLyDo.status).toBe(422);
    const cam = await goi('/thuc-thi/chan', { jwt: re.jwt, cookie: re.cookie, body: { dich: [{ loai: 'device', giaTri: TB2 }], hanhDong: 'ban', thoiHan: '24h', lyDo: 'Hook Frida xác nhận tay' } });
    expect(cam.status).toBe(201);
    expect(cam.json).toMatchObject({ loai: 'ngay', boQua: [] });
    expect(await db.prepare('SELECT status FROM devices WHERE id = ?').bind(TB2).first()).toEqual({ status: 'banned' });
    expect((await db.prepare("SELECT revoked_at FROM sessions WHERE id = 'p-s7b'").first<{ revoked_at: number | null }>())?.revoked_at).toBeGreaterThan(0);
    const lap = await goi('/thuc-thi/chan', { jwt: re.jwt, cookie: re.cookie, body: { dich: [{ loai: 'device', giaTri: TB2 }], hanhDong: 'ban', thoiHan: '24h', lyDo: 'Hook Frida xác nhận tay' } });
    expect(lap.json).toMatchObject({ tao: [], boQua: [`device:${TB2}`] });

    const id = (cam.json.tao as string[])[0] as string;
    expect((await goi('/thuc-thi/go', { jwt: re.jwt, cookie: re.cookie, body: { ids: [id], lyDo: 'Khiếu nại hợp lệ' } })).json).toMatchObject({ loai: 'ngay', go: 1 });
    expect((await db.prepare('SELECT status FROM devices WHERE id = ?').bind(TB2).first<{ status: string }>())?.status).not.toBe('banned');

    const dai = await goi('/thuc-thi/chan', { jwt: re.jwt, cookie: re.cookie, body: { dich: [{ loai: 'cidr', giaTri: '198.51.100.9/24' }], hanhDong: 'block', thoiHan: '7d', lyDo: 'Dải botnet quét API' } });
    expect(dai.json).toMatchObject({ loai: 'de-xuat' });
    const daiId = (dai.json.tao as string[])[0] as string;
    const ds = await goi('/thuc-thi?trangThai=cho-duyet', { jwt: re.jwt, cookie: re.cookie });
    expect((ds.json.ds as { id: string; target_value: string }[]).map((x) => [x.id, x.target_value])).toEqual([[daiId, '198.51.100.0/24']]);
    expect((await goi('/thuc-thi/duyet', { jwt: re.jwt, cookie: re.cookie, body: { id: daiId, dongY: true } })).status).toBe(403);
    await themQt('sa7@thu.vn', 'super_admin');
    const sa = await vaoSoc('sa7@thu.vn');
    expect((await goi('/thuc-thi/duyet', { jwt: sa.jwt, cookie: sa.cookie, body: { id: daiId, dongY: true } })).json).toEqual({ ok: true });
    expect(await db.prepare('SELECT approved_by FROM enforcements WHERE id = ?').bind(daiId).first()).toEqual({ approved_by: 'sa7@thu.vn' });

    const thu = await goi('/thiet-bi/thu-hoi-phien', { jwt: re.jwt, cookie: re.cookie, body: { thietBi: TB2, lyDo: 'Nghi lộ token phiên' } });
    expect(thu.json).toEqual({ ok: true, soPhien: 0 });
  });

  it('four-eyes hàng loạt: 202 yêu cầu; người tạo không tự duyệt; người khác duyệt -> có hiệu lực, approved_by khác created_by', async () => {
    await themQt('re2@thu.vn', 'security_admin');
    const re = await vaoSoc('re2@thu.vn');
    const yc = await goi('/thuc-thi/chan', {
      jwt: re.jwt,
      cookie: re.cookie,
      body: { dich: [{ loai: 'ip', giaTri: '192.0.2.10' }, { loai: 'ip', giaTri: '192.0.2.11' }], hanhDong: 'block', thoiHan: '1h', lyDo: 'Hai IP dò mật khẩu' },
    });
    expect(yc.status).toBe(202);
    const ycId = yc.json.yeuCau as string;
    expect((await goi('/yeu-cau-duyet/quyet', { jwt: re.jwt, cookie: re.cookie, body: { id: ycId, dongY: true } })).json.code).toBe('khong-tu-duyet');
    expect((await db.prepare("SELECT COUNT(*) AS n FROM enforcements WHERE target_value LIKE '192.0.2.%'").first<{ n: number }>())?.n).toBe(0);
    await themQt('sa8@thu.vn', 'super_admin');
    const s8 = await vaoSoc('sa8@thu.vn');
    const ds = await goi('/yeu-cau-duyet', { jwt: s8.jwt, cookie: s8.cookie });
    expect((ds.json.ds as { id: string }[]).map((x) => x.id)).toContain(ycId);
    const q = await goi('/yeu-cau-duyet/quyet', { jwt: s8.jwt, cookie: s8.cookie, body: { id: ycId, dongY: true, ghiChu: 'Đồng ý' } });
    expect(q.json).toMatchObject({ ok: true, ketQua: { boQua: [] } });
    const e = await db.prepare("SELECT created_by, approved_by, pending_approval FROM enforcements WHERE target_value LIKE '192.0.2.%' ORDER BY target_value").all();
    expect(e.results).toEqual([
      { created_by: 're2@thu.vn', approved_by: 'sa8@thu.vn', pending_approval: 0 },
      { created_by: 're2@thu.vn', approved_by: 'sa8@thu.vn', pending_approval: 0 },
    ]);
    expect((await goi('/yeu-cau-duyet/quyet', { jwt: s8.jwt, cookie: s8.cookie, body: { id: ycId, dongY: true } })).json.code).toBe('da-quyet');
    expect(
      (await db.prepare("SELECT action FROM audit_logs WHERE action LIKE 'four-eyes:%' ORDER BY rowid").all()).results.map((x) => (x as { action: string }).action),
    ).toEqual(['four-eyes:tao', 'four-eyes:duyet']);
  });

  it('cài đặt SOC: chỉ super_admin; tắt thuỷ vân -> /toi của mọi người phản ánh; audit có lý do', async () => {
    await themQt('v7@thu.vn', 'viewer');
    const v = await vaoSoc('v7@thu.vn');
    expect(((await goi('/toi', { jwt: v.jwt, cookie: v.cookie })).json.caiDat as { thuyVan: { bat: boolean } }).thuyVan.bat).toBe(true);
    const caiDat = { thuyVan: { bat: false, mucToiThieu: 'nhe' }, epCheKhiRoi: false };
    expect((await goi('/cai-dat-soc', { jwt: v.jwt, cookie: v.cookie, body: { caiDat, ghiChu: 'Muốn tắt thuỷ vân' } })).status).toBe(403);
    await themQt('sa9@thu.vn', 'super_admin');
    const sa = await vaoSoc('sa9@thu.vn');
    expect((await goi('/cai-dat-soc', { jwt: sa.jwt, cookie: sa.cookie, body: { caiDat, ghiChu: 'ngắn' } })).status).toBe(422);
    expect((await goi('/cai-dat-soc', { jwt: sa.jwt, cookie: sa.cookie, body: { caiDat, ghiChu: 'Màn hình trình chiếu nội bộ' } })).json).toEqual({ ok: true, caiDat });
    expect((await goi('/toi', { jwt: v.jwt, cookie: v.cookie })).json.caiDat).toEqual(caiDat);
    const doc = await goi('/cai-dat-soc', { jwt: sa.jwt, cookie: sa.cookie });
    expect((doc.json.lichSu as { actor: string }[])[0]?.actor).toBe('sa9@thu.vn');
  });
});
