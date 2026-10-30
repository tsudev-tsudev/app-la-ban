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
    bindings: { ACCESS_TEAM: access.team, ACCESS_AUD: `khac,${access.aud}`, SOC_NGUON: NGUON, ACCESS_DICH_VU: 'svc-thu.access' },
    outboundService: (req) => (new URL(req.url).pathname === '/cdn-cgi/access/certs' ? access.jwks() : new Response('x', { status: 404 })),
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
