import { describe, expect, it } from 'vitest';
import { chuoi } from '../i18n';

describe('S7c1: chuỗi khiếu nại / audit', () => {
  it('vi / en cùng bộ phím tắt + nhãn trạng thái khiếu nại', () => {
    const [vi, en] = [chuoi('vi'), chuoi('en')];
    expect(vi.dsPhimTat.map(([k]) => k)).toEqual(en.dsPhimTat.map(([k]) => k));
    expect(vi.dsPhimTat.map(([k]) => k)).toEqual(expect.arrayContaining(['g i', 'g a']));
    expect(Object.keys(vi.ttKhieuNai)).toEqual(Object.keys(en.ttKhieuNai));
  });

  it('thông báo kiểm chuỗi chỉ ra đúng dòng hỏng', () => {
    expect(chuoi('en').auHong(42, 41)).toContain('#42');
    expect(chuoi('vi').auNguyenVen(10, 3)).toContain('10');
    expect(chuoi('en').knDaChapNhan(2, 'Clean')).toBe('Accepted - lifted 2 restriction(s), device: Clean.');
  });
});
