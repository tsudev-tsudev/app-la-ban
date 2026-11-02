// Hàm thuần Admin SOC (S6): CBOR, WebAuthn, JWT Access, quyền, phiên, che PII, bộ lọc thiết bị.
import { describe, expect, it } from 'vitest';
import { chuanHoaEmail, kiemJwtAccess, LoiJwtAccess, tachDs } from '../src/thuan/access-jwt';
import { giaiMaCbor, LoiCbor } from '../src/thuan/cbor';
import { maHoaCursor } from '../src/thuan/cursor';
import { LoiApi } from '../src/thuan/loi';
import { b64urlTuByte } from '../src/thuan/ma-hoa';
import {
  cheIp,
  coQuyen,
  conStepUp,
  cookiePhien,
  docCookie,
  docLocThietBi,
  dsQuyen,
  PHIEN,
  tinChoVaiTro,
  tinhTrangPhien,
  truyVanThietBi,
} from '../src/thuan/soc';
import { coseSangJwk, kiemClientData, kiemDangKy, kiemXacThuc, LoiXacMinh, phanTichAuthData, rpIdTuNguon } from '../src/thuan/webauthn';
import { AccessGia, maHoaCbor, PasskeyGia } from './tich-hop/soc-gia';

const NGUON = ['https://soc.test'];

describe('CBOR', () => {
  it('giải mã map / mảng / số âm / byte / chuỗi / bool', () => {
    const b = maHoaCbor(new Map<never, never>([[1 as never, [-7, 'x', true, null, new Uint8Array([1, 2])] as never], ['k' as never, 300 as never]]));
    const { giaTri, ketThuc } = giaiMaCbor(b);
    expect(ketThuc).toBe(b.length);
    const m = giaTri as Map<unknown, unknown>;
    expect(m.get(1)).toEqual([-7, 'x', true, null, new Uint8Array([1, 2])]);
    expect(m.get('k')).toBe(300);
  });

  it('từ chối dữ liệu cụt, tag, độ dài 8 byte, lồng quá sâu', () => {
    expect(() => giaiMaCbor(new Uint8Array([0x42, 1]))).toThrow(LoiCbor);
    expect(() => giaiMaCbor(new Uint8Array([0xc0, 0]))).toThrow(LoiCbor);
    expect(() => giaiMaCbor(new Uint8Array([0x1b, 0, 0, 0, 0, 0, 0, 0, 1]))).toThrow(LoiCbor);
    expect(() => giaiMaCbor(new Uint8Array(Array(12).fill(0x81)))).toThrow(LoiCbor);
  });
});

describe('WebAuthn', () => {
  const cd = (o: object) => new TextEncoder().encode(JSON.stringify(o));
  it('clientData: sai loại / thách thức / nguồn / crossOrigin', () => {
    const ok = { type: 'webauthn.get', challenge: 'abc', origin: 'https://soc.test' };
    expect(kiemClientData(cd(ok), 'webauthn.get', 'abc', NGUON).origin).toBe('https://soc.test');
    const loi = (o: object, ma: string) => expect(() => kiemClientData(cd({ ...ok, ...o }), 'webauthn.get', 'abc', NGUON)).toThrow(new LoiXacMinh(ma as never));
    loi({ type: 'webauthn.create' }, 'sai-loai');
    loi({ challenge: 'xyz' }, 'sai-thach-thuc');
    loi({ origin: 'https://evil.test' }, 'sai-nguon');
    loi({ crossOrigin: true }, 'sai-nguon');
    expect(() => kiemClientData(new Uint8Array([0xff]), 'webauthn.get', 'abc', NGUON)).toThrow(LoiXacMinh);
  });

  it('authData ngắn / COSE lạ', () => {
    expect(() => phanTichAuthData(new Uint8Array(10))).toThrow(LoiXacMinh);
    expect(() => coseSangJwk(new Map<never, never>([[1 as never, 2 as never], [3 as never, -36 as never]]))).toThrow(new LoiXacMinh('thuat-toan'));
    expect(coseSangJwk(new Map<never, never>([[1 as never, 1 as never], [3 as never, -8 as never], [-1 as never, 6 as never], [-2 as never, new Uint8Array(32) as never]])).jwk.crv).toBe('Ed25519');
  });

  it('đăng ký + xác thực: đúng; thiếu UV; sai rp; chữ ký sai', async () => {
    const pk = await PasskeyGia.tao();
    const dk = await kiemDangKy(await pk.dangKy({ challenge: 'c1', rp: { id: 'soc.test' } }, 'https://soc.test'), 'c1', 'soc.test', NGUON);
    expect(dk.credentialId).toBe(pk.idB64);
    expect(dk.khoa.alg).toBe(-7);
    await expect(kiemDangKy(await pk.dangKy({ challenge: 'c1', rp: { id: 'soc.test' } }, 'https://soc.test', 0x41), 'c1', 'soc.test', NGUON)).rejects.toThrow(
      new LoiXacMinh('thieu-uv'),
    );
    await expect(kiemDangKy(await pk.dangKy({ challenge: 'c1', rp: { id: 'evil.test' } }, 'https://soc.test'), 'c1', 'soc.test', NGUON)).rejects.toThrow(
      new LoiXacMinh('sai-rp'),
    );
    const xt = await pk.xacThuc({ challenge: 'c2', rpId: 'soc.test' }, 'https://soc.test');
    expect((await kiemXacThuc(xt, dk.khoa, 0, 'c2', 'soc.test', NGUON)).signCount).toBe(1);
    await expect(kiemXacThuc(xt, dk.khoa, 1, 'c2', 'soc.test', NGUON)).rejects.toThrow(new LoiXacMinh('dem-lui'));
    const sai = { ...xt, signature: b64urlTuByte(new Uint8Array(70)) };
    await expect(kiemXacThuc(sai, dk.khoa, 0, 'c2', 'soc.test', NGUON)).rejects.toThrow(LoiXacMinh);
    const khac = await PasskeyGia.tao();
    const xtKhac = await khac.xacThuc({ challenge: 'c2', rpId: 'soc.test' }, 'https://soc.test');
    await expect(kiemXacThuc(xtKhac, dk.khoa, 0, 'c2', 'soc.test', NGUON)).rejects.toThrow(new LoiXacMinh('chu-ky'));
  });

  it('rpId chỉ từ origin trong danh sách', () => {
    expect(rpIdTuNguon('https://soc.test', NGUON)).toBe('soc.test');
    expect(rpIdTuNguon('https://evil.test', NGUON)).toBeNull();
    expect(rpIdTuNguon(undefined, NGUON)).toBeNull();
  });
});

describe('JWT Access', () => {
  it('đúng; sai iss; alg none; kid lạ; thiếu danh tính', async () => {
    const a = await AccessGia.tao();
    const p = { team: a.team, aud: [a.aud], bayGioGiay: Math.floor(Date.now() / 1000) };
    expect((await kiemJwtAccess(await a.jwt({ email: 'X@Y.vn' }), [a.jwk], p)).email).toBe('x@y.vn');
    const loi = async (t: string, ma: string) => expect(kiemJwtAccess(t, [a.jwk], p)).rejects.toThrow(new LoiJwtAccess(ma as never));
    await loi(await a.jwt({ email: 'x@y.vn', iss: 'https://khac.test' }), 'iss');
    await loi(await a.jwt({ email: 'x@y.vn' }, { alg: 'none' }), 'dinh-dang');
    await loi(await a.jwt({ email: 'x@y.vn' }, { kid: 'kid-2' }), 'kid');
    await loi(await a.jwt({}), 'danh-tinh');
    await loi(await a.jwt({ email: 'x@y.vn', nbf: p.bayGioGiay + 600 }), 'het-han');
    await loi('a.b', 'dinh-dang');
    await expect(kiemJwtAccess(null, [a.jwk], p)).rejects.toThrow(new LoiJwtAccess('thieu'));
    expect(tachDs(' a, ,b ')).toEqual(['a', 'b']);
  });

  it('chuẩn hoá email: Gmail bỏ dấu chấm / +nhãn / googlemail; miền khác chỉ chữ thường', async () => {
    expect(chuanHoaEmail('Dev.Nguyen.Trang@Gmail.com')).toBe('devnguyentrang@gmail.com');
    expect(chuanHoaEmail('dev+soc@googlemail.com')).toBe('dev@gmail.com');
    expect(chuanHoaEmail('Dev.A@TsuDev.com')).toBe('dev.a@tsudev.com');
    const a = await AccessGia.tao();
    const p = { team: a.team, aud: [a.aud], bayGioGiay: Math.floor(Date.now() / 1000) };
    expect((await kiemJwtAccess(await a.jwt({ email: 'dev.nguyen@gmail.com' }), [a.jwk], p)).email).toBe('devnguyen@gmail.com');
  });
});

describe('quyền + phiên + che PII', () => {
  it('vai trò thừa hưởng quyền thấp hơn', () => {
    expect(coQuyen('viewer', 'tong-quan')).toBe(true);
    expect(coQuyen('viewer', 'thiet-bi:chi-tiet')).toBe(false);
    expect(coQuyen('responder', 'thiet-bi:chi-tiet')).toBe(true);
    expect(coQuyen('security_admin', 'quan-tri-vien')).toBe(false);
    expect(dsQuyen('super_admin')).toHaveLength(21);
    expect(coQuyen('viewer', 'canh-bao:xem')).toBe(true);
    expect(coQuyen('viewer', 'canh-bao:xu-ly')).toBe(false);
    expect(coQuyen('analyst', 'canh-bao:xu-ly')).toBe(true);
  });

  it('tình trạng phiên: hợp lệ / nhàn rỗi / hết hạn / thu hồi / sai email; step-up 5 phút', () => {
    const p = { email: 'a@b.vn', created_at: 0, last_active: 1000, step_up_at: 1000, expires_at: PHIEN.tuyetDoiMs, revoked_at: null };
    expect(tinhTrangPhien(p, 'A@B.vn', 2000)).toBe('hop-le');
    expect(tinhTrangPhien(p, 'a@b.vn', 1000 + PHIEN.nhanRoiMs)).toBe('nhan-roi');
    expect(tinhTrangPhien(p, 'a@b.vn', PHIEN.tuyetDoiMs)).toBe('het-han');
    expect(tinhTrangPhien({ ...p, revoked_at: 5 }, 'a@b.vn', 2000)).toBe('thu-hoi');
    expect(tinhTrangPhien(p, 'c@b.vn', 2000)).toBe('sai-danh-tinh');
    expect(conStepUp(p, 1000 + PHIEN.stepUpMs - 1)).toBe(true);
    expect(conStepUp(p, 1000 + PHIEN.stepUpMs)).toBe(false);
  });

  it('cookie __Host- + đọc cookie chỉ nhận dạng base64url', () => {
    expect(cookiePhien('x'.repeat(43), 60)).toBe(`__Host-soc=${'x'.repeat(43)}; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=60`);
    expect(docCookie(`a=1; __Host-soc=${'y'.repeat(43)}`, '__Host-soc')).toBe('y'.repeat(43));
    expect(docCookie('__Host-soc=ngan', '__Host-soc')).toBeNull();
    expect(docCookie('__Host-soc=<script>aaaaaaaaaaaaaaaaaaaa', '__Host-soc')).toBeNull();
  });

  it('viewer nhận IP rút gọn, analyst nhận đầy đủ', () => {
    expect(cheIp('198.51.100.9', 'viewer')).toBe('198.51.100.0/24');
    expect(cheIp('198.51.100.9', 'analyst')).toBe('198.51.100.9');
    expect(cheIp(null, 'viewer')).toBeNull();
    const t = { loai: 'su-kien' as const, nhanLuc: 1, thietBi: 'x', ip: '2001:db8:1:2::9', quocGia: 'VN', ds: [], kichHoat: [], trangThai: null };
    expect(tinChoVaiTro(t, 'viewer').ip).toBe('2001:db8:1::/48');
  });
});

describe('bộ lọc thiết bị -> SQL', () => {
  it('ghép điều kiện có tham số, escape LIKE, phân trang keyset', () => {
    const loc = docLocThietBi({ trangThai: 'banned', q: '01JAB', ip: '10.1.2.0/24', asn: '7552', suKien: 'ROOT_DETECTED', sap: 'rui-ro', limit: '20' });
    const tv = truyVanThietBi({ ...loc, cursor: maHoaCursor({ t: 80, id: 'abc' }) }, 1_000_000_000_000);
    expect(tv.sql).toContain('d.status = ?');
    expect(tv.sql).toContain('ORDER BY d.risk_score DESC, d.id DESC');
    expect(tv.sql).toContain('(d.risk_score, d.id) < (?, ?)');
    expect(tv.thamSo).toEqual(['banned', '01JAB%', '10.1.2.%', 7552, 'ROOT_DETECTED', 1_000_000_000_000 - 30 * 86_400_000, 80, 'abc', 21]);
    expect(tv.gioiHan).toBe(20);
  });

  it('khoá lạ / IP sai / trạng thái lạ -> 400', () => {
    for (const q of [{ la: '1' }, { ip: '999.1.1.1' }, { ip: 'abc' }, { trangThai: 'xau' }, { q: "x' OR 1" }]) {
      expect(() => docLocThietBi(q)).toThrow(LoiApi);
    }
    expect(truyVanThietBi(docLocThietBi({ ip: '2001:db8::1' }), 0).thamSo).toEqual(['2001:db8::1', 51]);
  });
});
