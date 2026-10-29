import { describe, expect, it } from 'vitest';
import { emailTuDanhTinh } from './danh-tinh';
import { chuoi, ngonNgu } from '../i18n';

describe('emailTuDanhTinh', () => {
  it('chỉ nhận email hợp lệ từ get-identity', () => {
    expect(emailTuDanhTinh({ email: 'soc@tsudev.com', name: 'x' })).toBe('soc@tsudev.com');
    expect(emailTuDanhTinh({ email: 'khong la email' })).toBeNull();
    expect(emailTuDanhTinh({ email: 1 })).toBeNull();
    expect(emailTuDanhTinh(null)).toBeNull();
  });
});

describe('i18n admin', () => {
  it('vi mặc định, en theo lang, cùng bộ khoá', () => {
    expect(ngonNgu('en-GB')).toBe('en');
    expect(ngonNgu(undefined)).toBe('vi');
    expect(Object.keys(chuoi('en'))).toEqual(Object.keys(chuoi('vi')));
  });
});
