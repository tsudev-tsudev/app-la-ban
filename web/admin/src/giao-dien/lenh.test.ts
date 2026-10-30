import { describe, expect, it } from 'vitest';
import { diemKhop, khongDau, locLenh, nhanDang } from './lenh';

describe('bảng lệnh', () => {
  it('bỏ dấu tiếng Việt', () => {
    expect(khongDau('Cảnh báo Đang mở')).toBe('canh bao dang mo');
  });

  it('xếp hạng: đầu chuỗi > đầu từ > chứa > đủ từ', () => {
    expect(diemKhop('Cảnh báo', 'canh')).toBe(3);
    expect(diemKhop('Trung tâm cảnh báo', 'canh')).toBe(2);
    expect(diemKhop('Tài khoản', 'khoan')).toBe(2);
    expect(diemKhop('Thiết bị', 'et b')).toBe(1);
    expect(diemKhop('Đổi giao diện sáng tối', 'toi giao')).toBe(0);
    expect(diemKhop('Thiết bị', 'xyz')).toBe(-1);
    const ds = [{ nhan: 'Trung tâm cảnh báo' }, { nhan: 'Cảnh báo' }, { nhan: 'Tổng quan', tuKhoa: 'dashboard overview' }];
    expect(locLenh(ds, 'canh').map((x) => x.nhan)).toEqual(['Cảnh báo', 'Trung tâm cảnh báo']);
    expect(locLenh(ds, 'overview').map((x) => x.nhan)).toEqual(['Tổng quan']);
    expect(locLenh(ds, '')).toHaveLength(3);
  });

  it('nhận dạng ULID / UUID / IP', () => {
    expect(nhanDang('01JTB0000000000000000000AA')).toEqual({ loai: 'id', giaTri: '01JTB0000000000000000000AA' });
    expect(nhanDang(' 203.0.113.7 ')).toEqual({ loai: 'ip', giaTri: '203.0.113.7' });
    expect(nhanDang('203.0.113.0/24')?.loai).toBe('ip');
    expect(nhanDang('2001:db8::1')?.loai).toBe('ip');
    expect(nhanDang('999.1.1.1')).toBeNull();
    expect(nhanDang('canh bao')).toBeNull();
  });
});
