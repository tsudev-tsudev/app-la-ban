// M1a bước 3 trên workerd (Miniflare, Google giả lập): /v1/mua/xac-minh -> D1 quyen_loi -> /v1/status.quyenLoi;
// bản không phải Play -> 403; token giả -> 422 + PURCHASE_TOKEN_INVALID; vượt N thiết bị -> 403 + PURCHASE_TOKEN_SHARED;
// RTDN không JWT / sai aud -> 401, đúng -> cập nhật / hoàn tiền thu hồi; cron Voided Purchases; app Pro LICENSED -> pro_app.
import type { D1Database } from '@cloudflare/workers-types';
import type { Miniflare } from 'miniflare';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { sha256B64url } from '../src/attest/khoa';
import { b64urlTuByte, b64urlTuChuoi, chuoiDangKy } from '../src/thuan/ma-hoa';
import { taoMf } from './tich-hop/mf';
import { googleGia, taoKhoaPhien, taoServiceAccount, taoThietBiGia, tieuDeKy, tokenGia, type ThietBiGia } from './tich-hop/thiet-bi-gia';

let mf: Miniflare;
let db: D1Database;
const goc = 'https://compass-api.tsudev.com';
const GOI = 'com.tsudev.laban';
const GOI_PRO = 'com.tsudev.laban.pro';
const AUD = 'https://compass-api.tsudev.com/v1/play/rtdn';
const EMAIL = 'rtdn-day@du-an.iam.gserviceaccount.com';
let soIp = 0;

// --- Google Play Developer API giả: token -> trạng thái do test đặt ---
type GoiGia = { loai: 'sub'; trangThai: string; het: string; sanPham: string; ack?: boolean; lienKet?: string } | { loai: 'inapp'; purchaseState: number; sanPham: string };
const play = new Map<string, GoiGia>();
const daAck: string[] = [];
let dsHuy: string[] = [];
let khoaJwt: { jwk: JsonWebKey; ky: (claims: Record<string, unknown>) => Promise<string> };

async function googleMoRong(req: Request): Promise<Response> {
  const url = new URL(req.url);
  if (url.host === 'www.googleapis.com' && url.pathname === '/oauth2/v3/certs') return Response.json({ keys: [khoaJwt.jwk] });
  if (url.host !== 'androidpublisher.googleapis.com') return googleGia(req);
  if (req.headers.get('authorization') !== 'Bearer at-thu') return new Response('{}', { status: 401 });
  const p = decodeURIComponent(url.pathname);
  if (p.endsWith('/purchases/voidedpurchases')) return Response.json({ voidedPurchases: dsHuy.map((t) => ({ purchaseToken: t })) });
  const ack = /\/purchases\/(subscriptions|products)\/([^/]+)\/tokens\/(.+):acknowledge$/.exec(p);
  if (ack) {
    daAck.push(ack[3] as string);
    return new Response('', { status: 200 });
  }
  const sub = /\/purchases\/subscriptionsv2\/tokens\/(.+)$/.exec(p);
  const inapp = /\/purchases\/products\/([^/]+)\/tokens\/(.+)$/.exec(p);
  const token = sub?.[1] ?? inapp?.[2];
  const g = token ? play.get(token) : undefined;
  if (!g) return Response.json({ error: { code: 404 } }, { status: 404 });
  if (g.loai === 'sub' && sub) {
    return Response.json({
      subscriptionState: g.trangThai,
      latestOrderId: 'GPA.3300-0000',
      acknowledgementState: g.ack ? 'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED' : 'ACKNOWLEDGEMENT_STATE_PENDING',
      ...(g.lienKet ? { linkedPurchaseToken: g.lienKet } : {}),
      lineItems: [{ productId: g.sanPham, expiryTime: g.het, autoRenewingPlan: { autoRenewEnabled: true } }],
    });
  }
  if (g.loai === 'inapp' && inapp) return Response.json({ purchaseState: g.purchaseState, acknowledgementState: 0, orderId: 'GPA.1', productId: g.sanPham });
  return Response.json({ error: { code: 404 } }, { status: 404 });
}

const goi = async (duong: string, o: { body?: string; tieuDe?: Record<string, string> } = {}) => {
  const res = await mf.dispatchFetch(`${goc}${duong}`, {
    method: o.body === undefined ? 'GET' : 'POST',
    headers: { 'content-type': 'application/json', 'cf-connecting-ip': `192.0.2.${(soIp++ % 200) + 1}`, ...o.tieuDe },
    ...(o.body === undefined ? {} : { body: o.body }),
  });
  const vb = await res.text();
  // eslint-disable-next-line @typescript-eslint/no-explicit-any -- thân phản hồi tuỳ route trong test
  return { status: res.status, du: (vb ? JSON.parse(vb) : null) as Record<string, any> };
};

type ThietBiThu = { tb: ThietBiGia; id: string; token: string };

async function dangKy(o: { app?: string; goi?: string; giayPhep?: string } = {}): Promise<ThietBiThu> {
  const tb = await taoThietBiGia();
  const installationId = crypto.randomUUID();
  const ch = await goi('/v1/device/challenge', { body: JSON.stringify({ installationId }) });
  const thach = ch.du.thachThuc as string;
  const chuoi = chuoiDangKy(thach, installationId, tb.khoaCongKhai);
  const goiApp = o.goi ?? GOI;
  const integrityToken = tokenGia({
    requestDetails: { requestPackageName: goiApp, requestHash: await sha256B64url(chuoi), timestampMillis: String(Date.now()) },
    appIntegrity: { appRecognitionVerdict: o.app ?? 'PLAY_RECOGNIZED', packageName: goiApp },
    deviceIntegrity: { deviceRecognitionVerdict: ['MEETS_BASIC_INTEGRITY', 'MEETS_DEVICE_INTEGRITY'] },
    accountDetails: { appLicensingVerdict: o.giayPhep ?? 'UNEVALUATED' },
  });
  const r = await goi('/v1/device/register', {
    body: JSON.stringify({
      installationId,
      khoaCongKhai: tb.khoaCongKhai,
      thachThuc: thach,
      chuKy: await tb.ky(chuoi),
      nenTang: 'android',
      goi: goiApp,
      integrityToken,
      thongTin: { heDieuHanh: '13', model: 'SM-M325FV', phienBan: '0.2.0', build: 20, ngonNgu: 'vi' },
    }),
  });
  expect(r.status).toBe(201);
  return { tb, id: r.du.thietBiId, token: r.du.phien.accessToken };
}

const goiKy = async (t: ThietBiThu, duong: string, body?: unknown) => {
  const than = body === undefined ? undefined : JSON.stringify(body);
  return goi(duong, {
    ...(than === undefined ? {} : { body: than }),
    tieuDe: await tieuDeKy(t.tb, t.token, { phuongThuc: than === undefined ? 'GET' : 'POST', duong, ...(than === undefined ? {} : { than }) }),
  });
};

const xacMinh = (t: ThietBiThu, sanPham: string, token: string, goiApp = GOI) => goiKy(t, '/v1/mua/xac-minh', { sanPham, token, goi: goiApp });
const trangThai = async (t: ThietBiThu) => (await goiKy(t, '/v1/status')).du;

const choSuKien = async (thietBi: string | null, loai: string) => {
  for (let i = 0; i < 30; i++) {
    const r = await db
      .prepare(`SELECT COUNT(*) AS n FROM security_events WHERE type = ? AND ${thietBi ? 'device_id = ?' : 'device_id IS NULL'}`)
      .bind(loai, ...(thietBi ? [thietBi] : []))
      .first<{ n: number }>();
    if ((r?.n ?? 0) > 0) return r?.n ?? 0;
    await new Promise((x) => setTimeout(x, 50));
  }
  return 0;
};

const cho = async (dk: () => Promise<boolean>) => {
  for (let i = 0; i < 30; i++) {
    if (await dk()) return true;
    await new Promise((x) => setTimeout(x, 50));
  }
  return false;
};

const tokenMoi = () => `tok${crypto.randomUUID().replace(/-/g, '')}.AO-J1Oz`;
const sauMotNam = () => new Date(Date.now() + 365 * 86_400_000).toISOString();

async function jwtRtdn(claims: Record<string, unknown> = {}) {
  const giay = Math.floor(Date.now() / 1000);
  return khoaJwt.ky({ iss: 'https://accounts.google.com', aud: AUD, email: EMAIL, email_verified: true, iat: giay, exp: giay + 3600, ...claims });
}

async function rtdn(du: unknown, bearer?: string | null) {
  const body = JSON.stringify({ message: { data: btoa(JSON.stringify(du)), messageId: '1' }, subscription: 'projects/x/subscriptions/rtdn' });
  const jwt = bearer === undefined ? await jwtRtdn() : bearer;
  return goi('/v1/play/rtdn', { body, tieuDe: jwt ? { authorization: `Bearer ${jwt}` } : {} });
}

beforeAll(async () => {
  const cap = (await crypto.subtle.generateKey({ name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' }, true, [
    'sign',
    'verify',
  ])) as CryptoKeyPair;
  const jwk = { ...((await crypto.subtle.exportKey('jwk', cap.publicKey)) as JsonWebKey), kid: 'g-thu' };
  khoaJwt = {
    jwk,
    ky: async (claims) => {
      const dau = `${b64urlTuChuoi(JSON.stringify({ alg: 'RS256', kid: 'g-thu', typ: 'JWT' }))}.${b64urlTuChuoi(JSON.stringify(claims))}`;
      return `${dau}.${b64urlTuByte(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', cap.privateKey, new TextEncoder().encode(dau)))}`;
    },
  };
  mf = await taoMf(undefined, {
    bindings: {
      KHOA_PHIEN: await taoKhoaPhien(),
      PLAY_INTEGRITY_SA_JSON: await taoServiceAccount(),
      PI_GOI: `${GOI},${GOI_PRO}`,
      PI_CHUNG_CHI: '',
      PI_GOI_PRO: GOI_PRO,
      KHOA_QUYEN_LOI: btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32)))),
      QL_YEU_CAU_PLAY: '1',
      QL_THIET_BI_TOI_DA: '2',
      RTDN_AUD: AUD,
      RTDN_EMAIL: EMAIL,
    },
    outboundService: googleMoRong,
  });
  db = (await mf.getD1Database('DB')) as unknown as D1Database;
}, 60_000);
afterAll(async () => {
  await mf?.dispose();
});

describe('/v1/mua/xac-minh + /v1/status', () => {
  it('gói năm hợp lệ -> Pro tới hạn Google trả; token chỉ lưu băm + bản mã; tự acknowledge', async () => {
    const t = await dangKy();
    expect((await trangThai(t)).quyenLoi).toEqual({ pro: false, khongQuangCao: false, hetHan: null });
    const token = tokenMoi();
    const het = sauMotNam();
    play.set(token, { loai: 'sub', trangThai: 'SUBSCRIPTION_STATE_ACTIVE', het, sanPham: 'pro_nam' });
    const r = await xacMinh(t, 'pro_nam', token);
    expect(r).toMatchObject({ status: 200, du: { trangThai: 'active', quyenLoi: { pro: true, khongQuangCao: true, hetHan: Date.parse(het) } } });
    expect((await trangThai(t)).quyenLoi).toEqual({ pro: true, khongQuangCao: true, hetHan: Date.parse(het) });
    const dong = await db.prepare('SELECT * FROM quyen_loi WHERE source = ? ORDER BY created_at DESC LIMIT 1').bind('play_sub').first<Record<string, unknown>>();
    expect(JSON.stringify(dong)).not.toContain(token);
    expect(dong?.token_hash).toMatch(/^[0-9a-f]{64}$/);
    expect(String(dong?.token_enc)).toMatch(/^v1\./);
    expect(await cho(async () => daAck.includes(token))).toBe(true);
    expect(await cho(async () => (await db.prepare('SELECT acknowledged AS a FROM quyen_loi WHERE id = ?').bind(dong?.id).first<{ a: number }>())?.a === 1)).toBe(true);
    // Gọi lại (khôi phục trên cùng máy) không tạo dòng mới.
    expect((await xacMinh(t, 'pro_nam', token)).status).toBe(200);
    expect((await db.prepare('SELECT count(*) AS n FROM quyen_loi_devices WHERE device_id = ?').bind(t.id).first<{ n: number }>())?.n).toBe(1);
  });

  it('mua vĩnh viễn -> hetHan null', async () => {
    const t = await dangKy();
    const token = tokenMoi();
    play.set(token, { loai: 'inapp', purchaseState: 0, sanPham: 'pro_tron_doi' });
    expect((await xacMinh(t, 'pro_tron_doi', token)).du.quyenLoi).toEqual({ pro: true, khongQuangCao: true, hetHan: null });
  });

  it('bản tải ngoài Play (UNRECOGNIZED_VERSION) -> 403, không ghi quyền lợi', async () => {
    const t = await dangKy({ app: 'UNRECOGNIZED_VERSION' });
    const token = tokenMoi();
    play.set(token, { loai: 'inapp', purchaseState: 0, sanPham: 'pro_tron_doi' });
    expect(await xacMinh(t, 'pro_tron_doi', token)).toMatchObject({ status: 403, du: { code: 'khong-phai-ban-play' } });
    expect((await trangThai(t)).quyenLoi.pro).toBe(false);
  });

  it('token Google không biết -> 422 + PURCHASE_TOKEN_INVALID; gói / sản phẩm lạ -> 422; chưa ký -> 401', async () => {
    const t = await dangKy();
    expect(await xacMinh(t, 'pro_thang', tokenMoi())).toMatchObject({ status: 422, du: { code: 'token-sai' } });
    expect(await choSuKien(t.id, 'PURCHASE_TOKEN_INVALID')).toBe(1);
    expect((await xacMinh(t, 'pro_thang', tokenMoi(), 'com.ke.gia')).status).toBe(422);
    expect((await goiKy(t, '/v1/mua/xac-minh', { sanPham: 'pro_mien_phi', token: tokenMoi(), goi: GOI })).status).toBe(422);
    expect((await goi('/v1/mua/xac-minh', { body: JSON.stringify({ sanPham: 'pro_thang', token: tokenMoi(), goi: GOI }) })).status).toBe(401);
  });

  it('một token vượt N = 2 thiết bị hoạt động -> 403 + PURCHASE_TOKEN_SHARED; máy đã gắn vẫn làm mới được', async () => {
    const token = tokenMoi();
    play.set(token, { loai: 'sub', trangThai: 'SUBSCRIPTION_STATE_ACTIVE', het: sauMotNam(), sanPham: 'pro_thang', ack: true });
    const a = await dangKy();
    const b = await dangKy();
    const c = await dangKy();
    expect((await xacMinh(a, 'pro_thang', token)).status).toBe(200);
    expect((await xacMinh(b, 'pro_thang', token)).status).toBe(200);
    expect(await xacMinh(c, 'pro_thang', token)).toMatchObject({ status: 403, du: { code: 'token-qua-so-thiet-bi' } });
    expect(await choSuKien(c.id, 'PURCHASE_TOKEN_SHARED')).toBe(1);
    expect((await xacMinh(a, 'pro_thang', token)).status).toBe(200);
    expect((await trangThai(c)).quyenLoi.pro).toBe(false);
  });

  it('nâng cấp gói: token mới có linkedPurchaseToken -> token cũ bị thu hồi', async () => {
    const t = await dangKy();
    const cu = tokenMoi();
    const moi = tokenMoi();
    play.set(cu, { loai: 'sub', trangThai: 'SUBSCRIPTION_STATE_ACTIVE', het: sauMotNam(), sanPham: 'pro_thang', ack: true });
    play.set(moi, { loai: 'sub', trangThai: 'SUBSCRIPTION_STATE_ACTIVE', het: sauMotNam(), sanPham: 'pro_nam', ack: true, lienKet: cu });
    await xacMinh(t, 'pro_thang', cu);
    expect((await xacMinh(t, 'pro_nam', moi)).du.quyenLoi.pro).toBe(true);
    const { results } = await db
      .prepare('SELECT q.product_id AS p, q.state AS s, q.reason AS r FROM quyen_loi q JOIN quyen_loi_devices d ON d.entitlement_id = q.id WHERE d.device_id = ? ORDER BY p')
      .bind(t.id)
      .all<{ p: string; s: string; r: string | null }>();
    expect(results).toEqual([
      { p: 'pro_nam', s: 'active', r: null },
      { p: 'pro_thang', s: 'revoked', r: 'thay-the' },
    ]);
  });
});

describe('/v1/play/rtdn', () => {
  it('không JWT / sai aud / sai email -> 401 + RTDN_INVALID; đúng + thông báo thử -> 200', async () => {
    const thu = { packageName: GOI, testNotification: { version: '1.0' } };
    expect((await rtdn(thu, null)).status).toBe(401);
    expect((await rtdn(thu, await jwtRtdn({ aud: 'https://khac' }))).status).toBe(401);
    expect((await rtdn(thu, await jwtRtdn({ email: 'ke-gia@x.iam.gserviceaccount.com' }))).status).toBe(401);
    expect(await choSuKien(null, 'RTDN_INVALID')).toBeGreaterThan(0);
    expect(await rtdn(thu)).toMatchObject({ status: 200, du: { xuLy: 'thu' } });
  });

  it('gia hạn -> hạn mới; tạm giữ -> mất Pro; hoàn tiền -> thu hồi, Google không mở lại được', async () => {
    const t = await dangKy();
    const token = tokenMoi();
    const het1 = new Date(Date.now() + 30 * 86_400_000).toISOString();
    play.set(token, { loai: 'sub', trangThai: 'SUBSCRIPTION_STATE_ACTIVE', het: het1, sanPham: 'pro_thang', ack: true });
    await xacMinh(t, 'pro_thang', token);
    const het2 = new Date(Date.now() + 60 * 86_400_000).toISOString();
    play.set(token, { loai: 'sub', trangThai: 'SUBSCRIPTION_STATE_ACTIVE', het: het2, sanPham: 'pro_thang', ack: true });
    const sub = (kieu: number) => ({ packageName: GOI, subscriptionNotification: { notificationType: kieu, purchaseToken: token, subscriptionId: 'pro_thang' } });
    expect(await rtdn(sub(2))).toMatchObject({ status: 200, du: { xuLy: 'sub' } });
    expect((await trangThai(t)).quyenLoi.hetHan).toBe(Date.parse(het2));
    play.set(token, { loai: 'sub', trangThai: 'SUBSCRIPTION_STATE_ON_HOLD', het: het2, sanPham: 'pro_thang', ack: true });
    await rtdn(sub(5));
    expect((await trangThai(t)).quyenLoi.pro).toBe(false);
    play.set(token, { loai: 'sub', trangThai: 'SUBSCRIPTION_STATE_ACTIVE', het: het2, sanPham: 'pro_thang', ack: true });
    await rtdn(sub(1));
    expect((await trangThai(t)).quyenLoi.pro).toBe(true);
    expect(await rtdn({ packageName: GOI, voidedPurchaseNotification: { purchaseToken: token, orderId: 'GPA.1', productType: 1 } })).toMatchObject({ status: 200, du: { xuLy: 'hoan' } });
    expect((await trangThai(t)).quyenLoi.pro).toBe(false);
    await rtdn(sub(2));
    expect((await trangThai(t)).quyenLoi.pro).toBe(false);
  });

  it('gói lạ / dữ liệu hỏng -> 200 bỏ qua (Pub/Sub không gửi lại vô hạn)', async () => {
    expect(await rtdn({ packageName: 'com.khac', testNotification: {} })).toMatchObject({ status: 200, du: { xuLy: 'bo' } });
  });
});

describe('cron quét quyền lợi', () => {
  it('Voided Purchases -> thu hồi; gói sắp hết hạn được hỏi lại Google', async () => {
    const t = await dangKy();
    const huy = tokenMoi();
    play.set(huy, { loai: 'inapp', purchaseState: 0, sanPham: 'pro_tron_doi' });
    await xacMinh(t, 'pro_tron_doi', huy);
    const sap = tokenMoi();
    const t2 = await dangKy();
    play.set(sap, { loai: 'sub', trangThai: 'SUBSCRIPTION_STATE_ACTIVE', het: new Date(Date.now() + 3600_000).toISOString(), sanPham: 'pro_thang', ack: true });
    await xacMinh(t2, 'pro_thang', sap);
    const het = sauMotNam();
    play.set(sap, { loai: 'sub', trangThai: 'SUBSCRIPTION_STATE_ACTIVE', het, sanPham: 'pro_thang', ack: true });
    dsHuy = [huy];
    const kq = await goi('/thu/quet-quyen-loi', { body: '{}' });
    expect(kq.status).toBe(200);
    expect(kq.du.thuHoi).toBeGreaterThanOrEqual(1);
    expect(kq.du.kiemLai).toBeGreaterThanOrEqual(1);
    expect((await trangThai(t)).quyenLoi.pro).toBe(false);
    expect((await trangThai(t2)).quyenLoi.hetHan).toBe(Date.parse(het));
    dsHuy = [];
  });
});

describe('app Pro (Q56)', () => {
  it('bản Play LICENSED -> pro_app vĩnh viễn; bản sao UNLICENSED -> không Pro + PRO_UNLICENSED', async () => {
    const t = await dangKy({ goi: GOI_PRO, giayPhep: 'LICENSED' });
    expect(await cho(async () => (await trangThai(t)).quyenLoi.pro === true)).toBe(true);
    expect((await trangThai(t)).quyenLoi).toEqual({ pro: true, khongQuangCao: true, hetHan: null });
    const sao = await dangKy({ goi: GOI_PRO, giayPhep: 'UNLICENSED' });
    expect(await choSuKien(sao.id, 'PRO_UNLICENSED')).toBe(1);
    expect((await trangThai(sao)).quyenLoi.pro).toBe(false);
    // Bản miễn phí LICENSED không phải app Pro -> không cấp.
    const mienPhi = await dangKy({ giayPhep: 'LICENSED' });
    await new Promise((x) => setTimeout(x, 200));
    expect((await trangThai(mienPhi)).quyenLoi.pro).toBe(false);
  });
});
