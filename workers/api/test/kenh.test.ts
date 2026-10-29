// S3 - hàm thuần: chuỗi ký request (vector dùng chung với Dart), header ký, mã REF, latest.json.
import { describe, expect, it } from 'vitest';
import { sha256HexByte } from '../src/thuan/bam';
import { docLatest, LOAI_CHI_SERVER, maRef, refChoTrangThai } from '../src/thuan/kenh';
import { chuoiYeuCau, docTieuDeKy, kiemTruocKy, maHoaRfc3986, querySapXep } from '../src/thuan/ky-yeu-cau';

// Cùng vector ở packages/security_sdk/test/chuoi_ky_test.dart - đổi một bên phải đổi cả hai.
const VECTOR = {
  phuongThuc: 'post',
  duongDan: '/v1/events',
  query: 'z=2&a=b c&a=%C3%A1&m=x+y&k=!*',
  than: '{"a":1}',
  bamThan: '015abd7f5cc57a2dd94b7590f04ad8084273905ee33ec5cebeae62276a97f862',
  ts: 1761800000000,
  nonce: 'AAAAAAAAAAAAAAAAAAAAAA',
  chuoi:
    'POST\n/v1/events\na=b%20c&a=%C3%A1&k=%21%2A&m=x%20y&z=2\n015abd7f5cc57a2dd94b7590f04ad8084273905ee33ec5cebeae62276a97f862\n1761800000000\nAAAAAAAAAAAAAAAAAAAAAA',
};

describe('chuỗi ký request (Spec §7.5)', () => {
  it('vector dùng chung với Dart', async () => {
    expect(await sha256HexByte(new TextEncoder().encode(VECTOR.than) as Uint8Array<ArrayBuffer>)).toBe(VECTOR.bamThan);
    expect(chuoiYeuCau(VECTOR)).toBe(VECTOR.chuoi);
  });

  it('query: rỗng, sắp theo khoá rồi giá trị, mã hoá RFC 3986', () => {
    expect(querySapXep('')).toBe('');
    expect(querySapXep('b=2&a=3&a=1')).toBe('a=1&a=3&b=2');
    expect(querySapXep('x=%2F%3F')).toBe('x=%2F%3F');
    expect(maHoaRfc3986("a b!'()*~._-")).toBe('a%20b%21%27%28%29%2A~._-');
  });

  it('GET không thân: băm chuỗi rỗng', async () => {
    const rong = await sha256HexByte(new Uint8Array(0));
    expect(rong).toBe('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');
    expect(chuoiYeuCau({ phuongThuc: 'GET', duongDan: '/v1/status', query: '', bamThan: rong, ts: 1, nonce: 'n'.repeat(16) })).toBe(
      `GET\n/v1/status\n\n${rong}\n1\n${'n'.repeat(16)}`,
    );
  });
});

describe('header ký', () => {
  const du: Record<string, string> = {
    'x-timestamp': '1761800000000',
    'x-nonce': 'A'.repeat(22),
    'x-signature': 'B'.repeat(96),
    'x-device-id': '01JC0000000000000000000000',
  };
  const lay = (o: Record<string, string>) => (ten: string) => o[ten];

  it('đủ -> đọc được; thiếu / sai dạng -> null', () => {
    expect(docTieuDeKy(lay(du))).toEqual({ thietBi: du['x-device-id'], ts: 1761800000000, nonce: du['x-nonce'], chuKy: du['x-signature'] });
    expect(docTieuDeKy(lay({ ...du, 'x-device-id': '' }))).toBeNull();
    for (const [k, v] of [
      ['x-timestamp', '17618000000.5'],
      ['x-timestamp', '-1761800000000'],
      ['x-nonce', 'ngắn'],
      ['x-signature', 'B'.repeat(60)],
      ['x-signature', `${'B'.repeat(95)}=`],
    ] as const) {
      expect(docTieuDeKy(lay({ ...du, [k]: v }))).toBeNull();
    }
    const khongId = { ...du };
    delete khongId['x-device-id'];
    expect(docTieuDeKy(lay(khongId))?.thietBi).toBeNull();
  });

  it('thiết bị khác claim / lệch giờ > 60 s', () => {
    const t = docTieuDeKy(lay(du));
    if (!t) throw new Error('null');
    expect(kiemTruocKy(t, du['x-device-id'] as string, t.ts + 60_000, 60_000)).toBeNull();
    expect(kiemTruocKy(t, du['x-device-id'] as string, t.ts - 60_001, 60_000)).toBe('lech-gio');
    expect(kiemTruocKy(t, '01JC0000000000000000000001', t.ts, 60_000)).toBe('thiet-bi-khac');
  });
});

describe('kênh: REF, latest.json, loại sự kiện', () => {
  it('mã REF từ phần ngẫu nhiên của ULID; chỉ khi restricted / banned', () => {
    expect(maRef('01JC00000000000000ABCDEFGH')).toBe('REF-00ABC-DEFGH');
    expect(() => maRef('khong-phai-ulid')).toThrow(RangeError);
    expect(refChoTrangThai('clean', '01JC00000000000000ABCDEFGH')).toBeNull();
    expect(refChoTrangThai('suspicious', '01JC00000000000000ABCDEFGH')).toBeNull();
    expect(refChoTrangThai('banned', '01JC00000000000000ABCDEFGH')).toBe('REF-00ABC-DEFGH');
    expect(refChoTrangThai('restricted', '01JC00000000000000ABCDEFGH')).toBe('REF-00ABC-DEFGH');
  });

  it('latest.json R0 -> phiên bản + mã; sai dạng -> null', () => {
    expect(docLatest(JSON.stringify({ phienBan: '0.1.0-beta.5', maPhienBan: 5, tep: [] }))).toEqual({ phienBan: '0.1.0-beta.5', maPhienBan: 5 });
    expect(docLatest(null)).toBeNull();
    expect(docLatest('{')).toBeNull();
    expect(docLatest(JSON.stringify({ phienBan: '<script>', maPhienBan: 5 }))).toBeNull();
    expect(docLatest(JSON.stringify({ phienBan: '1.0.0', maPhienBan: 0 }))).toBeNull();
  });

  it('loại chỉ server sinh', () => {
    expect(LOAI_CHI_SERVER.has('TOKEN_REUSE')).toBe(true);
    expect(LOAI_CHI_SERVER.has('ROOT_DETECTED')).toBe(false);
  });
});
