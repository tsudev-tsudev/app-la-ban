// S2 - hàm thuần định danh / attestation / phiên + WebCrypto (Node có crypto.subtle như workerd).
import { describe, expect, it } from 'vitest';
import { kiemChuKyThietBi, kiemJwt, kyJwt, napKhoaPhien, nhapKhoaThietBi, sha256B64url } from '../src/attest/khoa';
import { b64urlTuByte, byteTuB64url, chuoiDangKy, derSangTho, digestSangHex } from '../src/thuan/ma-hoa';
import { AN_HAN_XOAY_MS, docBearer, quyetDinhLamMoi, tachJwt, taoClaim, type DongPhien } from '../src/thuan/phien';
import { danhGiaPhanQuyet, duTinCay, schemaPhanQuyet, type KyVong } from '../src/thuan/play-integrity';
import { taoKhoaPhien, taoThietBiGia, thoSangDer } from './tich-hop/thiet-bi-gia';

const CC = 'cf09e7243bca9ab5d29dc788bbd31ba71efaebab7d69583d98bbfc5184a7f6bd';
const ccB64 = b64urlTuByte(Uint8Array.from(CC.match(/../g)?.map((h) => parseInt(h, 16)) ?? []));

describe('ma-hoa', () => {
  it('base64url khứ hồi mọi độ dài, từ chối ký tự lạ', () => {
    for (let n = 0; n < 40; n++) {
      const b = Uint8Array.from({ length: n }, (_, i) => (i * 37 + n) % 256);
      expect(byteTuB64url(b64urlTuByte(b))).toEqual(b);
    }
    expect(byteTuB64url('ab+c')).toBeNull();
    expect(byteTuB64url('abcde')).toBeNull();
  });
  it('DER <-> thô: số có 0x00 dẫn đầu, số ngắn, sai cấu trúc', () => {
    const tho = new Uint8Array(64);
    tho[0] = 0x80;
    tho[63] = 1;
    tho.fill(7, 33, 40);
    const der = thoSangDer(tho);
    expect(der[3]).toBe(33);
    expect(derSangTho(der)).toEqual(tho);
    expect(derSangTho(Uint8Array.of(0x30, 6, 2, 1, 1, 2, 1, 2))?.slice(30, 33)).toEqual(Uint8Array.of(0, 1, 0));
    expect(derSangTho(Uint8Array.of(0x31, 6, 2, 1, 1, 2, 1, 2))).toBeNull();
    expect(derSangTho(Uint8Array.of(0x30, 7, 2, 1, 1, 2, 1, 2, 0))).toBeNull();
    expect(derSangTho(Uint8Array.of(0x30, 6, 2, 1, 1, 2, 2, 2))).toBeNull();
  });
  it('digest chứng chỉ: hex có / không dấu hai chấm, base64url, base64 chuẩn', () => {
    expect(digestSangHex(CC.toUpperCase().match(/../g)?.join(':') ?? '')).toBe(CC);
    expect(digestSangHex(ccB64)).toBe(CC);
    expect(digestSangHex(`${ccB64.replace(/-/g, '+').replace(/_/g, '/')}=`)).toBe(CC);
    expect(digestSangHex('abc')).toBeNull();
  });
});

describe('khoá thiết bị + chữ ký Android (DER)', () => {
  it('chữ ký đúng chuỗi -> đạt; chuỗi khác / chữ ký hỏng -> trượt', async () => {
    const tb = await taoThietBiGia();
    const k = await nhapKhoaThietBi(tb.khoaCongKhai);
    if (!k) throw new Error('khoá');
    expect(k.jkt).toMatch(/^[A-Za-z0-9_-]{43}$/);
    const chuoi = chuoiDangKy('t'.repeat(43), crypto.randomUUID(), tb.khoaCongKhai);
    const ky = await tb.ky(chuoi);
    expect(await kiemChuKyThietBi(k.khoa, chuoi, ky)).toBe(true);
    expect(await kiemChuKyThietBi(k.khoa, `${chuoi}x`, ky)).toBe(false);
    expect(await kiemChuKyThietBi(k.khoa, chuoi, `${ky.slice(0, -4)}AAAA`)).toBe(false);
    expect(await kiemChuKyThietBi(k.khoa, chuoi, 'khong-phai-der')).toBe(false);
  });
  it('khoá sai dạng / không phải P-256 -> null', async () => {
    expect(await nhapKhoaThietBi('AAAA')).toBeNull();
    const rsa = (await crypto.subtle.generateKey({ name: 'RSA-PSS', modulusLength: 1024, publicExponent: Uint8Array.of(1, 0, 1), hash: 'SHA-256' }, true, ['sign', 'verify'])) as CryptoKeyPair;
    expect(await nhapKhoaThietBi(b64urlTuByte((await crypto.subtle.exportKey('spki', rsa.publicKey)) as ArrayBuffer))).toBeNull();
  });
  it('thumbprint RFC 7638 = SHA-256 của JSON chuẩn {crv,kty,x,y}', async () => {
    const tb = await taoThietBiGia();
    const k = await nhapKhoaThietBi(tb.khoaCongKhai);
    if (!k) throw new Error('khoá');
    const jwk = (await crypto.subtle.exportKey('jwk', k.khoa)) as JsonWebKey;
    expect(k.jkt).toBe(await sha256B64url(`{"crv":"P-256","kty":"EC","x":"${jwk.x}","y":"${jwk.y}"}`));
  });
});

describe('JWT phiên ES256', () => {
  const claim = (bayGio: number) => taoClaim({ moiTruong: 'test', thietBi: 'TB', phien: 'P', jkt: 'j'.repeat(43), muc: 'device', bayGio });
  it('ký -> kiểm đạt; hết hạn / sai môi trường / sửa payload / kid lạ -> null', async () => {
    const k = await napKhoaPhien(await taoKhoaPhien('a'));
    const bay = Date.now();
    const jwt = await kyJwt(k, claim(bay));
    expect(await kiemJwt(k, jwt, 'test', bay + 1000)).toMatchObject({ sub: 'TB', sid: 'P', lvl: 'device' });
    expect(await kiemJwt(k, jwt, 'test', bay + 15 * 60_000 + 1000)).toBeNull();
    expect(await kiemJwt(k, jwt, 'prod', bay)).toBeNull();
    const [h, , s] = jwt.split('.');
    const sua = `${h}.${b64urlTuByte(new TextEncoder().encode(JSON.stringify({ ...claim(bay), sub: 'KHAC' })))}.${s}`;
    expect(await kiemJwt(k, sua, 'test', bay)).toBeNull();
    const k2 = await napKhoaPhien(await taoKhoaPhien('b'));
    expect(await kiemJwt(k2, jwt, 'test', bay)).toBeNull();
  });
  it('xoay khoá: mảng JWK - khoá đầu ký, khoá cũ vẫn kiểm', async () => {
    const cu = await taoKhoaPhien('cu');
    const moi = await taoKhoaPhien('moi');
    const kCu = await napKhoaPhien(cu);
    const jwtCu = await kyJwt(kCu, claim(Date.now()));
    const kXoay = await napKhoaPhien(`[${moi},${cu}]`);
    expect(kXoay.kid).toBe('moi');
    expect(await kiemJwt(kXoay, jwtCu, 'test', Date.now())).not.toBeNull();
  });
  it('tachJwt từ chối alg khác, claim thừa, chữ ký sai độ dài', () => {
    const p = (o: unknown) => b64urlTuByte(new TextEncoder().encode(JSON.stringify(o)));
    const c = claim(Date.now());
    const s = b64urlTuByte(new Uint8Array(64));
    expect(tachJwt(`${p({ alg: 'ES256', typ: 'JWT', kid: 'a' })}.${p(c)}.${s}`)).not.toBeNull();
    expect(tachJwt(`${p({ alg: 'none', typ: 'JWT', kid: 'a' })}.${p(c)}.${s}`)).toBeNull();
    expect(tachJwt(`${p({ alg: 'ES256', typ: 'JWT', kid: 'a' })}.${p({ ...c, admin: true })}.${s}`)).toBeNull();
    expect(tachJwt(`${p({ alg: 'ES256', typ: 'JWT', kid: 'a' })}.${p(c)}.${b64urlTuByte(new Uint8Array(63))}`)).toBeNull();
    expect(tachJwt('a.b')).toBeNull();
  });
  it('docBearer', () => {
    expect(docBearer('Bearer abc.def.ghijklmnopqrstu')).toBe('abc.def.ghijklmnopqrstu');
    expect(docBearer('bearer abc.def.ghijklmnopqrstu')).toBeNull();
    expect(docBearer(undefined)).toBeNull();
  });
});

describe('quyết định làm mới (xoay + phát hiện dùng lại)', () => {
  const d = (o: Partial<DongPhien>): DongPhien => ({ id: 'P1', device_id: 'T', chuoi: 'P0', expires_at: 2000, revoked_at: null, thay_boi: null, xoay_luc: null, ...o });
  it('các nhánh', () => {
    expect(quyetDinhLamMoi(null, 1000)).toEqual({ loai: 'khong-co' });
    expect(quyetDinhLamMoi(d({}), 1000)).toEqual({ loai: 'xoay' });
    expect(quyetDinhLamMoi(d({}), 2000)).toEqual({ loai: 'het-han' });
    expect(quyetDinhLamMoi(d({ revoked_at: 900 }), 1000)).toEqual({ loai: 'thu-hoi' });
    expect(quyetDinhLamMoi(d({ revoked_at: 900, thay_boi: 'P2', xoay_luc: 900 }), 900 + AN_HAN_XOAY_MS)).toEqual({ loai: 'an-han' });
    expect(quyetDinhLamMoi(d({ revoked_at: 900, thay_boi: 'P2', xoay_luc: 900 }), 901 + AN_HAN_XOAY_MS)).toEqual({ loai: 'dung-lai', chuoi: 'P0' });
    expect(quyetDinhLamMoi(d({ chuoi: null, revoked_at: 900, thay_boi: 'P2', xoay_luc: 1 }), 1e9)).toEqual({ loai: 'dung-lai', chuoi: 'P1' });
  });
});

describe('đánh giá phán quyết Play Integrity', () => {
  const bay = 1_800_000_000_000;
  const kv: KyVong = { dsGoi: ['com.tsudev.laban'], dsChungChi: [CC], requestHash: 'H', bayGio: bay };
  const pq = (o: { req?: object; app?: object | null; tb?: string[] | null; acc?: object } = {}) =>
    schemaPhanQuyet.parse({
      requestDetails: { requestPackageName: 'com.tsudev.laban', requestHash: 'H', timestampMillis: String(bay - 1000), ...o.req },
      ...(o.app === null
        ? {}
        : { appIntegrity: { appRecognitionVerdict: 'PLAY_RECOGNIZED', packageName: 'com.tsudev.laban', certificateSha256Digest: [ccB64], versionCode: '5', ...o.app } }),
      ...(o.tb === null ? {} : { deviceIntegrity: { deviceRecognitionVerdict: o.tb ?? ['MEETS_DEVICE_INTEGRITY'] } }),
      accountDetails: { appLicensingVerdict: 'LICENSED', ...o.acc },
    });
  it('thiết bị đạt -> device / strong / basic', () => {
    expect(danhGiaPhanQuyet(pq(), kv)).toMatchObject({ loai: 'muc', muc: 'device', lyDo: [] });
    expect(danhGiaPhanQuyet(pq({ tb: ['MEETS_BASIC_INTEGRITY', 'MEETS_DEVICE_INTEGRITY', 'MEETS_STRONG_INTEGRITY'] }), kv)).toMatchObject({ muc: 'strong' });
    expect(danhGiaPhanQuyet(pq({ tb: ['MEETS_BASIC_INTEGRITY'] }), kv)).toMatchObject({ muc: 'basic' });
    expect(danhGiaPhanQuyet(pq({ tb: ['MEETS_VIRTUAL_INTEGRITY'] }), kv)).toMatchObject({ muc: 'basic', tinHieu: { ao: true } });
  });
  it('bản cài từ Play ký khoá Google tạo (Q63) đạt khi có trong danh sách, trượt khi chỉ có khoá upload', () => {
    const play = 'b84d419196141b48c74609824b3ff41ebcc3f51f86c94b561fbbd20440f18b7b';
    const playB64 = b64urlTuByte(Uint8Array.from(play.match(/../g)?.map((h) => parseInt(h, 16)) ?? []));
    const hai = { ...kv, dsChungChi: [CC, play] };
    expect(danhGiaPhanQuyet(pq({ app: { certificateSha256Digest: [playB64] } }), hai)).toMatchObject({ muc: 'device', lyDo: [] });
    expect(danhGiaPhanQuyet(pq(), hai)).toMatchObject({ muc: 'device', lyDo: [] });
    expect(danhGiaPhanQuyet(pq({ app: { certificateSha256Digest: [playB64] } }), kv)).toMatchObject({ muc: 'failed', lyDo: ['chung-chi'] });
  });
  it('APK tải ngoài Play (UNRECOGNIZED_VERSION) đúng chứng chỉ vẫn đạt', () => {
    expect(danhGiaPhanQuyet(pq({ app: { appRecognitionVerdict: 'UNRECOGNIZED_VERSION' }, acc: { appLicensingVerdict: 'UNEVALUATED' } }), kv)).toMatchObject({ muc: 'device', lyDo: [] });
  });
  it('thiết bị không đạt / app sai chứng chỉ (đóng gói lại) -> failed', () => {
    expect(danhGiaPhanQuyet(pq({ tb: [] }), kv)).toMatchObject({ muc: 'failed', lyDo: ['thiet-bi'] });
    expect(danhGiaPhanQuyet(pq({ tb: null }), kv)).toMatchObject({ muc: 'failed' });
    expect(danhGiaPhanQuyet(pq({ app: { certificateSha256Digest: [b64urlTuByte(new Uint8Array(32))] } }), kv)).toMatchObject({ muc: 'failed', lyDo: ['chung-chi'] });
    expect(danhGiaPhanQuyet(pq({ app: { certificateSha256Digest: [] } }), kv)).toMatchObject({ muc: 'failed', lyDo: ['thieu-chung-chi'] });
    expect(danhGiaPhanQuyet(pq({ app: { packageName: 'com.khac' } }), kv)).toMatchObject({ muc: 'failed', lyDo: ['goi-app'] });
  });
  it('staging không kiểm chứng chỉ; app UNEVALUATED không có chứng chỉ không bị phạt', () => {
    expect(danhGiaPhanQuyet(pq({ app: { certificateSha256Digest: [b64urlTuByte(new Uint8Array(32))] } }), { ...kv, dsChungChi: [] })).toMatchObject({ muc: 'device' });
    expect(danhGiaPhanQuyet(pq({ app: { appRecognitionVerdict: 'UNEVALUATED', certificateSha256Digest: undefined } }), kv)).toMatchObject({ muc: 'device' });
  });
  it('token không thuộc yêu cầu này -> từ chối (phát lại / sai gói / quá cũ / tương lai)', () => {
    expect(danhGiaPhanQuyet(pq({ req: { requestHash: 'KHAC' } }), kv)).toEqual({ loai: 'tu-choi', lyDo: 'request-hash' });
    expect(danhGiaPhanQuyet(pq({ req: { requestPackageName: 'com.tsudev.laban.dev' } }), kv)).toEqual({ loai: 'tu-choi', lyDo: 'goi-yeu-cau' });
    expect(danhGiaPhanQuyet(pq({ req: { timestampMillis: String(bay - 11 * 60_000) } }), kv)).toEqual({ loai: 'tu-choi', lyDo: 'token-cu' });
    expect(danhGiaPhanQuyet(pq({ req: { timestampMillis: bay + 120_000 } }), kv)).toEqual({ loai: 'tu-choi', lyDo: 'token-cu' });
  });
  it('mức đủ tin cậy cho tính năng nhạy cảm', () => {
    expect(['strong', 'device', 'basic', 'failed', 'unverified'].map((m) => duTinCay(m as never))).toEqual([true, true, false, false, false]);
  });
});
