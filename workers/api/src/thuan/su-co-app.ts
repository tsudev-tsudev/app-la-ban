// Báo cáo sự cố app (S10b, QUYET_DINH Q49): schema nhận từ app + dấu vết gom nhóm + thống kê không lỗi. Hàm thuần.
import { z } from 'zod';
import { sha256Hex } from './bam';

export const LO_SU_CO_TOI_DA = 10;

export const schemaLoSuCo = z.strictObject({
  suCo: z
    .array(
      z.strictObject({
        loai: z.enum(['flutter', 'dart']),
        kieu: z.string().min(1).max(120),
        thongDiep: z.string().max(500),
        nganXep: z.string().max(8000),
        phienBan: z.string().regex(/^[0-9A-Za-z.+-]{1,40}$/),
        luc: z.number().int().positive(),
      }),
    )
    .min(1)
    .max(LO_SU_CO_TOI_DA),
});

/**
 * Một khung ngăn xếp -> dạng ổn định: bỏ số thứ tự '#nn' và địa chỉ tuyệt đối 'abs <hex>' (đổi theo ASLR mỗi lần chạy),
 * giữ 'virt' + ký hiệu (bản che mã) hoặc hàm + tệp:dòng (bản thường).
 */
export function chuanHoaKhung(dong: string): string {
  return dong
    .replace(/^#\d+\s+/, '')
    .replace(/\babs [0-9a-f]+\s*/i, '')
    .replace(/\s+/g, ' ')
    .trim();
}

export async function dauVetSuCo(kieu: string, nganXep: string): Promise<string> {
  const khung = nganXep
    .split('\n')
    .filter((d) => /^#\d+/.test(d.trim()))
    .slice(0, 5)
    .map((d) => chuanHoaKhung(d.trim()));
  return (await sha256Hex(`${kieu}|${khung.join('|')}`)).slice(0, 16);
}

/** Che thêm ở server (app đã che): email, IPv4 đầy đủ -> chỉ giữ dải /24. */
export function cheThongDiep(s: string): string {
  return s
    .replace(/[\w.+-]+@[\w-]+\.[\w.-]+/g, '<email>')
    .replace(/\b(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.\d{1,3}\b/g, '$1.$2.$3.x');
}

/** Tỷ lệ thiết bị không gặp sự cố (%) trong cửa sổ; chưa có thiết bị hoạt động -> null. */
export function tyLeKhongLoi(thietBiHoatDong: number, thietBiCoLoi: number): number | null {
  if (thietBiHoatDong <= 0) return null;
  const ty = (1 - Math.min(thietBiCoLoi, thietBiHoatDong) / thietBiHoatDong) * 100;
  return Math.round(ty * 100) / 100;
}
