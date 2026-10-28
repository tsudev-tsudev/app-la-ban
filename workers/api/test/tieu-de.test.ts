import { describe, expect, it } from 'vitest';
import { ganTieuDe, TIEU_DE_BAO_MAT } from '../src/thuan/tieu-de';

describe('ganTieuDe', () => {
  it('thêm đủ header bảo mật nền', () => {
    const h = ganTieuDe(new Headers());
    for (const ten of Object.keys(TIEU_DE_BAO_MAT)) expect(h.get(ten)).toBe(TIEU_DE_BAO_MAT[ten]);
    expect(h.get('strict-transport-security')).toMatch(/max-age=31536000/);
  });

  it('giữ header route đã đặt, bỏ x-powered-by', () => {
    const h = ganTieuDe(new Headers({ 'cache-control': 'public, max-age=60', 'x-powered-by': 'x' }));
    expect(h.get('cache-control')).toBe('public, max-age=60');
    expect(h.has('x-powered-by')).toBe(false);
  });
});
