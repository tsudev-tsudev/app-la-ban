import { describe, expect, it } from 'vitest';
import { bitDauVet, doMoLop, laMucThuyVan, LUOI_CHAM, maDauVet, nhanThuyVan } from './dau-vet';

describe('dấu vết thuỷ vân', () => {
  it('mã ổn định trong một giờ, đổi theo giờ và theo người, không phân biệt hoa thường', async () => {
    const t = Date.UTC(2026, 9, 30, 8, 5);
    const a = await maDauVet('soc@tsudev.com', t);
    expect(a).toMatch(/^[0-9a-f]{8}$/);
    expect(await maDauVet(' SOC@tsudev.com ', t + 50 * 60_000)).toBe(a);
    expect(await maDauVet('soc@tsudev.com', t + 60 * 60_000)).not.toBe(a);
    expect(await maDauVet('khac@tsudev.com', t)).not.toBe(a);
  });

  it('36 bit = 32 bit mã + 4 bit chẵn lẻ, vừa lưới 6x6', () => {
    const b = bitDauVet('ff00a501');
    expect(b).toHaveLength(LUOI_CHAM * LUOI_CHAM);
    expect(b.slice(0, 8)).toEqual([1, 1, 1, 1, 1, 1, 1, 1]);
    expect(b.slice(16, 24)).toEqual([1, 0, 1, 0, 0, 1, 0, 1]);
    expect(b.slice(32)).toEqual([0, 0, 0, 1]);
    expect(bitDauVet('XYZ')).toEqual([]);
  });

  it('độ mờ: nhẹ < chuẩn < tăng cường, luôn > 0', () => {
    expect(doMoLop('nhe', false)).toBeGreaterThan(0);
    expect(doMoLop('nhe', false)).toBeLessThan(doMoLop('chuan', false));
    expect(doMoLop('chuan', false)).toBeLessThan(doMoLop('nhe', true));
    expect(laMucThuyVan('tat')).toBe(false);
  });

  it('nhãn theo giờ Việt Nam kèm mã', () => {
    expect(nhanThuyVan('a@b.vn', Date.UTC(2026, 9, 30, 17, 9), 'abcd1234')).toBe('a@b.vn · 2026-10-31 00:09 · #abcd1234');
  });
});
