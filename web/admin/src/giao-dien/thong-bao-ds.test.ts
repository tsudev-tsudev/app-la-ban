import { describe, expect, it } from 'vitest';
import { themThongBao, TOI_DA_THONG_BAO, type MotThongBao } from './thong-bao-ds';

const tb = (id: number, noiDung: string, loai: MotThongBao['loai'] = 'loi'): MotThongBao => ({ id, loai, noiDung });

describe('danh sách toast (A9c)', () => {
  it('trùng nội dung + loại: thay tại chỗ bằng id mới, không chồng', () => {
    const ds = [tb(1, 'Mất mạng'), tb(2, 'Đã lưu', 'ok')];
    const moi = themThongBao(ds, tb(3, 'Mất mạng'));
    expect(moi.map((x) => x.id)).toEqual([3, 2]);
    expect(moi).toHaveLength(2);
  });

  it('khác loại thì là toast khác', () => {
    expect(themThongBao([tb(1, 'X', 'ok')], tb(2, 'X', 'loi'))).toHaveLength(2);
  });

  it(`giữ tối đa ${TOI_DA_THONG_BAO}, bỏ cái cũ nhất`, () => {
    let ds: MotThongBao[] = [];
    for (let i = 1; i <= 6; i++) ds = themThongBao(ds, tb(i, `tin ${i}`));
    expect(ds.map((x) => x.id)).toEqual([3, 4, 5, 6]);
  });

  it('lỗi lặp 20 lần chỉ còn một toast', () => {
    let ds: MotThongBao[] = [];
    for (let i = 1; i <= 20; i++) ds = themThongBao(ds, tb(i, 'Không làm mới được'));
    expect(ds).toEqual([tb(20, 'Không làm mới được')]);
  });
});
