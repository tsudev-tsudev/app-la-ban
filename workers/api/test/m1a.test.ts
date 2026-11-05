// M1a bước 3 (SEC-IAP) - hàm thuần quyền lợi: đọc phản hồi Google, RTDN, JWT OIDC, gộp quyền lợi, mã hoá token.
import { describe, expect, it } from 'vitest';
import { b64urlTuByte, b64urlTuChuoi } from '../src/thuan/ma-hoa';
import {
  conHieuLuc,
  docGoiDangKy,
  docMuaMotLan,
  docRtdn,
  giaiMaTokenQl,
  kidJwt,
  kiemJwtGoogle,
  LoiJwtGoogle,
  maHoaToken,
  tongHopQuyenLoi,
  trangThaiGhiDe,
  goiBanTrongApp,
} from '../src/thuan/quyen-loi';

const BAY_GIO = Date.parse('2026-11-03T12:00:00Z');
const GOI = 'com.tsudev.laban';
const TOKEN = 'abcdefghijklmnop.AO-J1Oz_token-thu';

const goi = (trangThai: string, o: Record<string, unknown> = {}) => ({
  subscriptionState: trangThai,
  latestOrderId: 'GPA.1234-5678',
  acknowledgementState: 'ACKNOWLEDGEMENT_STATE_PENDING',
  lineItems: [{ productId: 'pro_nam', expiryTime: '2027-11-03T12:00:00Z', autoRenewingPlan: { autoRenewEnabled: true } }],
  ...o,
});

describe('docGoiDangKy', () => {
  it('ánh xạ trạng thái Google -> trạng thái nội bộ, đọc hạn / tự gia hạn / thử', () => {
    const kq = docGoiDangKy(goi('SUBSCRIPTION_STATE_ACTIVE', { testPurchase: {} }), 'pro_nam');
    expect(kq).toEqual({
      trangThai: 'active',
      hetHan: Date.parse('2027-11-03T12:00:00Z'),
      tuDongGiaHan: true,
      daXacNhan: false,
      maDon: 'GPA.1234-5678',
      thu: true,
      taiKhoan: null,
      tokenLienKet: null,
    });
    expect(docGoiDangKy(goi('SUBSCRIPTION_STATE_IN_GRACE_PERIOD'), 'pro_nam')?.trangThai).toBe('grace');
    expect(docGoiDangKy(goi('SUBSCRIPTION_STATE_ON_HOLD'), 'pro_nam')?.trangThai).toBe('on_hold');
    expect(docGoiDangKy(goi('SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED'), 'pro_nam')?.trangThai).toBe('expired');
    expect(docGoiDangKy(goi('LA'), 'pro_nam')?.trangThai).toBe('pending');
  });
  it('token của sản phẩm khác -> null; thiếu expiryTime -> hạn 0 (không có hiệu lực)', () => {
    expect(docGoiDangKy(goi('SUBSCRIPTION_STATE_ACTIVE'), 'pro_thang')).toBeNull();
    const kq = docGoiDangKy(goi('SUBSCRIPTION_STATE_ACTIVE', { lineItems: [{ productId: 'pro_nam' }] }), 'pro_nam');
    expect(kq?.hetHan).toBe(0);
    expect(conHieuLuc(kq?.trangThai ?? '', kq?.hetHan ?? 0, BAY_GIO)).toBe(false);
  });
});

describe('docMuaMotLan', () => {
  it('0 đã mua (vĩnh viễn), 2 chờ, 1 huỷ -> thu hồi; purchaseType 0 = mua thử', () => {
    expect(docMuaMotLan({ purchaseState: 0, acknowledgementState: 1, purchaseType: 0 }, 'pro_vinh_vien')).toMatchObject({
      trangThai: 'active',
      hetHan: null,
      daXacNhan: true,
      thu: true,
    });
    expect(docMuaMotLan({ purchaseState: 2 }, 'pro_vinh_vien')?.trangThai).toBe('pending');
    expect(docMuaMotLan({ purchaseState: 1 }, 'pro_vinh_vien')?.trangThai).toBe('revoked');
    expect(docMuaMotLan({ purchaseState: 0, productId: 'khac' }, 'pro_vinh_vien')).toBeNull();
  });
});

describe('tongHopQuyenLoi / conHieuLuc / trangThaiGhiDe', () => {
  it('không dòng / chỉ dòng hết hạn -> không Pro', () => {
    expect(tongHopQuyenLoi([], BAY_GIO)).toEqual({ pro: false, khongQuangCao: false, hetHan: null });
    expect(tongHopQuyenLoi([{ state: 'active', expires_at: BAY_GIO - 1 }, { state: 'revoked', expires_at: null }], BAY_GIO).pro).toBe(false);
  });
  it('đã huỷ gia hạn nhưng còn hạn vẫn Pro; lấy hạn xa nhất; có vĩnh viễn -> hetHan null', () => {
    expect(tongHopQuyenLoi([{ state: 'canceled', expires_at: BAY_GIO + 10 }, { state: 'grace', expires_at: BAY_GIO + 99 }], BAY_GIO)).toEqual({
      pro: true,
      khongQuangCao: true,
      hetHan: BAY_GIO + 99,
    });
    expect(tongHopQuyenLoi([{ state: 'active', expires_at: BAY_GIO + 10 }, { state: 'active', expires_at: null }], BAY_GIO).hetHan).toBeNull();
    expect(conHieuLuc('on_hold', BAY_GIO + 10, BAY_GIO)).toBe(false);
    expect(conHieuLuc('paused', null, BAY_GIO)).toBe(false);
  });
  it('đã thu hồi thì Google không mở lại được', () => {
    expect(trangThaiGhiDe('revoked', 'active')).toBe('revoked');
    expect(trangThaiGhiDe('expired', 'active')).toBe('active');
    expect(trangThaiGhiDe(null, 'grace')).toBe('grace');
  });
});

const b64 = (o: unknown) => btoa(JSON.stringify(o));

describe('docRtdn', () => {
  it('gói đăng ký / mua một lần / hoàn tiền / thử', () => {
    const dsGoi = [GOI];
    expect(docRtdn(b64({ packageName: GOI, eventTimeMillis: '1', subscriptionNotification: { notificationType: 2, purchaseToken: TOKEN, subscriptionId: 'pro_thang' } }), dsGoi)).toEqual({
      loai: 'sub',
      goi: GOI,
      token: TOKEN,
      sanPham: 'pro_thang',
      kieu: 2,
    });
    expect(docRtdn(b64({ packageName: GOI, oneTimeProductNotification: { notificationType: 1, purchaseToken: TOKEN, sku: 'pro_vinh_vien' } }), dsGoi)).toMatchObject({ loai: 'inapp' });
    expect(docRtdn(b64({ packageName: GOI, voidedPurchaseNotification: { purchaseToken: TOKEN, orderId: 'GPA.1', productType: 1 } }), dsGoi)).toEqual({ loai: 'hoan', goi: GOI, token: TOKEN });
    expect(docRtdn(b64({ packageName: GOI, testNotification: { version: '1.0' } }), dsGoi)).toEqual({ loai: 'thu', goi: GOI });
  });
  it('gói lạ / sản phẩm lạ / sai loại sản phẩm / dữ liệu hỏng -> bỏ qua', () => {
    const dsGoi = [GOI];
    expect(docRtdn(b64({ packageName: 'com.khac', testNotification: {} }), dsGoi)).toEqual({ loai: 'bo', lyDo: 'goi' });
    expect(docRtdn(b64({ packageName: GOI, subscriptionNotification: { notificationType: 2, purchaseToken: TOKEN, subscriptionId: 'pro_vinh_vien' } }), dsGoi)).toEqual({ loai: 'bo', lyDo: 'san-pham' });
    expect(docRtdn(b64({ packageName: GOI, subscriptionNotification: { notificationType: 2, purchaseToken: 'ngan', subscriptionId: 'pro_thang' } }), dsGoi)).toEqual({ loai: 'bo', lyDo: 'dang' });
    expect(docRtdn('%%%', dsGoi)).toEqual({ loai: 'bo', lyDo: 'base64' });
    expect(docRtdn(btoa('khong-json'), dsGoi)).toEqual({ loai: 'bo', lyDo: 'json' });
    expect(docRtdn(b64({ packageName: GOI }), dsGoi)).toEqual({ loai: 'bo', lyDo: 'khong-loai' });
  });
});

async function taoKhoaRsa(kid = 'g1') {
  const cap = (await crypto.subtle.generateKey({ name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' }, true, [
    'sign',
    'verify',
  ])) as CryptoKeyPair;
  const jwk = { ...((await crypto.subtle.exportKey('jwk', cap.publicKey)) as JsonWebKey), kid };
  const ky = async (claims: Record<string, unknown>, h: Record<string, unknown> = { alg: 'RS256', kid }) => {
    const dau = `${b64urlTuChuoi(JSON.stringify(h))}.${b64urlTuChuoi(JSON.stringify(claims))}`;
    const cks = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', cap.privateKey, new TextEncoder().encode(dau));
    return `${dau}.${b64urlTuByte(cks)}`;
  };
  return { jwk, ky };
}

describe('kiemJwtGoogle', () => {
  const giay = Math.floor(BAY_GIO / 1000);
  const p = { aud: 'https://compass-api.tsudev.com/v1/play/rtdn', email: 'rtdn@du-an.iam.gserviceaccount.com', bayGioGiay: giay };
  const dung = { iss: 'https://accounts.google.com', aud: p.aud, email: p.email, email_verified: true, iat: giay - 10, exp: giay + 3600 };

  it('JWT đúng -> qua; kid đọc được', async () => {
    const k = await taoKhoaRsa();
    const t = await k.ky(dung);
    await expect(kiemJwtGoogle(t, [k.jwk], p)).resolves.toBeUndefined();
    expect(kidJwt(t)).toBe('g1');
    await expect(kiemJwtGoogle(await k.ky({ ...dung, iss: 'accounts.google.com' }), [k.jwk], p)).resolves.toBeUndefined();
  });

  it.each([
    ['aud', { aud: 'https://khac' }],
    ['email', { email: 'ke-gia@x.iam.gserviceaccount.com' }],
    ['email', { email_verified: false }],
    ['iss', { iss: 'https://ke-gia.example' }],
    ['het-han', { exp: giay - 3600 }],
    ['het-han', { iat: giay + 3600 }],
  ])('claim sai -> %s', async (ma, sai) => {
    const k = await taoKhoaRsa();
    await expect(kiemJwtGoogle(await k.ky({ ...dung, ...sai }), [k.jwk], p)).rejects.toMatchObject({ ma });
  });

  it('khoá khác / kid lạ / thiếu / alg none -> từ chối', async () => {
    const k = await taoKhoaRsa();
    const khac = await taoKhoaRsa();
    await expect(kiemJwtGoogle(await khac.ky(dung), [k.jwk], p)).rejects.toMatchObject({ ma: 'chu-ky' });
    await expect(kiemJwtGoogle(await k.ky(dung, { alg: 'RS256', kid: 'la' }), [k.jwk], p)).rejects.toMatchObject({ ma: 'kid' });
    await expect(kiemJwtGoogle(await k.ky(dung, { alg: 'none', kid: 'g1' }), [k.jwk], p)).rejects.toMatchObject({ ma: 'dinh-dang' });
    await expect(kiemJwtGoogle(null, [k.jwk], p)).rejects.toBeInstanceOf(LoiJwtGoogle);
    await expect(kiemJwtGoogle('a.b', [k.jwk], p)).rejects.toMatchObject({ ma: 'dinh-dang' });
  });
});

describe('maHoaToken / giaiMaTokenQl', () => {
  const khoa = btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32))));
  it('khứ hồi; bản mã không chứa token, mỗi lần một IV', async () => {
    const a = await maHoaToken(khoa, TOKEN);
    const b = await maHoaToken(khoa, TOKEN);
    expect(a).not.toBe(b);
    expect(a).not.toContain(TOKEN);
    expect(a.startsWith('v1.')).toBe(true);
    expect(await giaiMaTokenQl(khoa, a)).toBe(TOKEN);
  });
  it('sai khoá / sửa bản mã / sai định dạng -> null; khoá sai độ dài -> ném', async () => {
    const a = await maHoaToken(khoa, TOKEN);
    const khac = btoa(String.fromCharCode(...crypto.getRandomValues(new Uint8Array(32))));
    expect(await giaiMaTokenQl(khac, a)).toBeNull();
    const [v, iv, ma] = a.split('.') as [string, string, string];
    expect(await giaiMaTokenQl(khoa, `${v}.${iv}.${ma.slice(0, -2)}AA`)).toBeNull();
    expect(await giaiMaTokenQl(khoa, 'v2.x.y')).toBeNull();
    await expect(maHoaToken(btoa('ngan'), TOKEN)).rejects.toThrow('khoa-quyen-loi-sai-do-dai');
  });
});

describe('goiBanTrongApp (M2, Q56)', () => {
  it('bỏ gói app Pro khỏi luồng bán trong app / RTDN / Voided Purchases', () => {
    const ds = ['com.tsudev.laban', 'com.tsudev.laban.pro'];
    expect(goiBanTrongApp(ds, ['com.tsudev.laban.pro'])).toEqual(['com.tsudev.laban']);
    expect(goiBanTrongApp(ds, [])).toEqual(ds);
    expect(goiBanTrongApp([], ['com.tsudev.laban.pro'])).toEqual([]);
  });
});
