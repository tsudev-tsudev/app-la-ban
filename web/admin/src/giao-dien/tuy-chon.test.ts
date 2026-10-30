import { describe, expect, it } from 'vitest';
import { docTuyChon, MAC_DINH } from './tuy-chon';

describe('tuỳ chọn hiển thị', () => {
  it('rỗng / hỏng -> mặc định; nhận chủ đề cũ (S6)', () => {
    expect(docTuyChon(null)).toEqual(MAC_DINH);
    expect(docTuyChon('{hong')).toEqual(MAC_DINH);
    expect(docTuyChon(null, 'dark').chuDe).toBe('dark');
  });

  it('giá trị lạ bị bỏ, không thể tắt thuỷ vân', () => {
    expect(docTuyChon(JSON.stringify({ chuDe: 'tim', matDo: 'gon', thuyVan: 'tat', cheKhiRoi: 'co' }))).toEqual({
      chuDe: null,
      matDo: 'gon',
      thuyVan: 'nhe',
      cheKhiRoi: false,
    });
    expect(docTuyChon(JSON.stringify({ chuDe: 'light', thuyVan: 'chuan', cheKhiRoi: true }))).toMatchObject({ chuDe: 'light', thuyVan: 'chuan', cheKhiRoi: true });
  });
});
