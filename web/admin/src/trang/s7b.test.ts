import { describe, expect, it } from 'vitest';
import { tachDich } from './CanThiep';
import { docCauHinhForm } from './CauHinhNguyCo';
import { dinhDangCuaSo, tachSuKien } from './Luat';

describe('S7b: biểu mẫu rule / can thiệp / cấu hình', () => {
  it('tách mã sự kiện: chữ hoa, bỏ trùng, báo phần sai', () => {
    expect(tachSuKien('hook_frida, APP_REPACKAGED;HOOK_FRIDA')).toEqual({ ds: ['HOOK_FRIDA', 'APP_REPACKAGED'], sai: [] });
    expect(tachSuKien('ROOT, x, 9AB')).toEqual({ ds: ['ROOT'], sai: ['X', '9AB'] });
  });

  it('cửa sổ hiển thị theo đơn vị lớn nhất chia hết', () => {
    expect(dinhDangCuaSo(86_400, 'en')).toBe('1 day');
    expect(dinhDangCuaSo(600, 'en')).toBe('10 minutes');
    expect(dinhDangCuaSo(7200, 'vi')).toContain('2');
  });

  it('tách đích: mỗi dòng / dấu phẩy, bỏ trống + trùng', () => {
    expect(tachDich('203.0.113.7\n 203.0.113.8 ,203.0.113.7\n\n')).toEqual(['203.0.113.7', '203.0.113.8']);
  });

  it('đọc form cấu hình: giữ trường không có trên form, TTL theo ngày, thêm loại mới hợp lệ', () => {
    const goc = { diem: { ROOT: 25 }, nguong: { suspicious: 30, restricted: 60, banned: 90 }, hoiPhuc: { diemMoiTuan: 5, san: 0 }, ttlBac: [86_400_000, 7 * 86_400_000], underAttack: true, diemToiDa: 1000 };
    const f = new FormData();
    f.set('diem.ROOT', '30');
    f.set('nguong.banned', '120');
    f.set('ttl.1', '14');
    f.set('diemMoi.loai', 'new_signal');
    f.set('diemMoi.diem', '7');
    const kq = docCauHinhForm(f, goc);
    expect(kq.diem).toEqual({ ROOT: 30, NEW_SIGNAL: 7 });
    expect(kq.nguong).toEqual({ suspicious: 30, restricted: 60, banned: 120 });
    expect(kq.ttlBac).toEqual([86_400_000, 14 * 86_400_000]);
    expect(kq.underAttack).toBe(true);
  });
});
