import { describe, expect, it } from 'vitest';
import { docTuyChon, MAC_DINH, tuyChonHieuLuc } from './tuy-chon';

describe('tuỳ chọn hiển thị', () => {
  it('rỗng / hỏng -> mặc định; nhận chủ đề cũ (S6)', () => {
    expect(docTuyChon(null)).toEqual(MAC_DINH);
    expect(docTuyChon('{hong')).toEqual(MAC_DINH);
    expect(docTuyChon(null, 'dark').chuDe).toBe('dark');
  });

  it('giá trị lạ bị bỏ, người xem không tự tắt được thuỷ vân', () => {
    expect(docTuyChon(JSON.stringify({ chuDe: 'tim', matDo: 'gon', thuyVan: 'tat', cheKhiRoi: 'co' }))).toEqual({
      chuDe: null,
      matDo: 'gon',
      thuyVan: 'nhe',
      cheKhiRoi: false,
    });
    expect(docTuyChon(JSON.stringify({ chuDe: 'light', thuyVan: 'chuan', cheKhiRoi: true }))).toMatchObject({ chuDe: 'light', thuyVan: 'chuan', cheKhiRoi: true });
  });

  it('cài đặt Super Admin (S7b): tắt thuỷ vân toàn hệ thống, ép độ đậm tối thiểu, ép che khi rời', () => {
    expect(tuyChonHieuLuc(MAC_DINH, undefined)).toEqual({ thuyVanBat: true, thuyVan: 'nhe', cheKhiRoi: false });
    expect(tuyChonHieuLuc(MAC_DINH, { thuyVan: { bat: false, mucToiThieu: 'nhe' }, epCheKhiRoi: false }).thuyVanBat).toBe(false);
    expect(tuyChonHieuLuc(MAC_DINH, { thuyVan: { bat: true, mucToiThieu: 'chuan' }, epCheKhiRoi: true })).toEqual({ thuyVanBat: true, thuyVan: 'chuan', cheKhiRoi: true });
    expect(tuyChonHieuLuc({ ...MAC_DINH, thuyVan: 'chuan', cheKhiRoi: true }, { thuyVan: { bat: true, mucToiThieu: 'nhe' }, epCheKhiRoi: false })).toMatchObject({ thuyVan: 'chuan', cheKhiRoi: true });
  });
});
