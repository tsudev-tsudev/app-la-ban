import { afterEach, describe, expect, it, vi } from 'vitest';
import { choKhien, LoiSoc } from '../api';

/** Phần tử giả (môi trường test không có DOM): chỉ cần thuộc tính. */
function phanTu(ds: string[]) {
  const tt = new Set(ds);
  return { hasAttribute: (t: string) => tt.has(t), them: (t: string) => tt.add(t) };
}

class QuanSatGia {
  static cuoi: QuanSatGia | null = null;
  ngat = false;
  constructor(readonly goiLai: () => void) {
    QuanSatGia.cuoi = this;
  }
  observe() {}
  disconnect() {
    this.ngat = true;
  }
}

afterEach(() => {
  vi.unstubAllGlobals();
  vi.useRealTimers();
});

describe('S11 choKhien', () => {
  it('khiên đã kiểm, không nghi -> gọi API ngay', async () => {
    await expect(choKhien(phanTu(['data-khien-san']) as unknown as HTMLElement)).resolves.toBeUndefined();
  });

  it('khiên đang nghi -> không gọi API (LoiSoc khien-nghi)', async () => {
    const kq = choKhien(phanTu(['data-khien-san', 'data-khien-nghi']) as unknown as HTMLElement);
    await expect(kq).rejects.toBeInstanceOf(LoiSoc);
    await expect(kq).rejects.toMatchObject({ ma: 'khien-nghi' });
  });

  it('chờ khiên báo xong; khiên không nạp được -> sau 3 giây vẫn gọi (Worker là chốt chặn)', async () => {
    vi.stubGlobal('MutationObserver', QuanSatGia);
    const pt = phanTu([]);
    const cho = choKhien(pt as unknown as HTMLElement);
    pt.them('data-khien-san');
    QuanSatGia.cuoi?.goiLai();
    await expect(cho).resolves.toBeUndefined();
    expect(QuanSatGia.cuoi?.ngat).toBe(true);

    vi.useFakeTimers();
    const het = choKhien(phanTu([]) as unknown as HTMLElement);
    vi.advanceTimersByTime(3000);
    await expect(het).resolves.toBeUndefined();
  });
});
