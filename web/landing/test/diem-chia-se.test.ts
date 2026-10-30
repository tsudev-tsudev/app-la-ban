import { describe, expect, it } from 'vitest';
import { crc32, giaiMaToken, linkBanDo, linkMoApp, tokenTuDuongDan } from '../src/lib/diem-chia-se';

// Vector sinh từ app (packages/waypoint_feature/test/domain/token_chia_se_test.dart) - đổi định dạng phải đổi cả hai.
const DAY_DU =
  'AQMMiLI3PxfC3mtJ0gAAAAB7C0jhu5MgR8awxqFtI0fhurdwIOG7nyBj4buVbmcgxJHhu4FuIE5n4buNYyBTxqFu8n1obQ';
const TOI_GIAN = 'AQAAAAAAAAAAAP____8BQRQuxN8';

describe('giaiMaToken', () => {
  it('crc32 chuẩn zlib', () => {
    expect(crc32(new TextEncoder().encode('123456789'))).toBe(0xcbf43926);
  });
  it('đọc đúng vector của app', () => {
    expect(giaiMaToken(DAY_DU, 1700000000)).toEqual({
      diem: {
        ten: 'Hồ Gươm',
        viDo: 21.0285111,
        kinhDo: 105.8521822,
        caoDo: 12.3,
        ghiChu: 'Gặp ở cổng đền Ngọc Sơn',
        hetHan: 1800000000,
      },
    });
    expect(giaiMaToken(TOI_GIAN, 0)).toEqual({
      diem: { ten: 'A', viDo: 0, kinhDo: 0, caoDo: null, ghiChu: '', hetHan: 0xffffffff },
    });
  });
  it('hết hạn / hỏng / sửa 1 ký tự', () => {
    expect(giaiMaToken(DAY_DU, 1800000001)).toEqual({ loi: 'hetHan' });
    for (const t of ['', 'AQ', '%%', DAY_DU.slice(0, -3), DAY_DU.slice(0, 10) + (DAY_DU[10] === 'A' ? 'B' : 'A') + DAY_DU.slice(11), 'A'.repeat(5000)]) {
      expect(giaiMaToken(t, 0)).toEqual({ loi: 'hong' });
    }
  });
  it('byte phiên bản 2 (CRC đúng) -> phienBanLa', () => {
    const b = Uint8Array.from(atob(TOI_GIAN.replace(/-/g, '+').replace(/_/g, '/') + '='), (c) => c.charCodeAt(0));
    const than = b.slice(0, b.length - 4);
    than[0] = 2;
    const c = crc32(than);
    const day = new Uint8Array([...than, c >>> 24, (c >>> 16) & 255, (c >>> 8) & 255, c & 255]);
    const t = btoa(String.fromCharCode(...day)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
    expect(giaiMaToken(t, 0)).toEqual({ loi: 'phienBanLa' });
  });
});

describe('đường dẫn + link', () => {
  it('tokenTuDuongDan', () => {
    expect(tokenTuDuongDan('/w/AbC_-1')).toBe('AbC_-1');
    expect(tokenTuDuongDan('/w/AbC/')).toBe('AbC');
    expect(tokenTuDuongDan('/w/')).toBeNull();
    expect(tokenTuDuongDan('/w/a/b')).toBeNull();
    expect(tokenTuDuongDan('/x/abc')).toBeNull();
  });
  it('link app + bản đồ', () => {
    expect(linkMoApp('AQ')).toBe(
      'intent://compass.tsudev.com/w/AQ#Intent;scheme=https;package=com.tsudev.laban;S.browser_fallback_url=https%3A%2F%2Fcompass.tsudev.com%2Ftai-ve%2F;end',
    );
    expect(linkBanDo({ viDo: 21.0285111, kinhDo: 105.8521822 })).toBe(
      'https://www.openstreetmap.org/?mlat=21.028511&mlon=105.852182#map=16/21.028511/105.852182',
    );
  });
});
