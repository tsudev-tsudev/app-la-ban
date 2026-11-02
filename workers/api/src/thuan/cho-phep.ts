// R2 (phát hành Play, runbook phat-hanh-play mục 4) - allow-list quản lý từ SOC: miễn trừ thiết bị / IP / dải / ASN khỏi
// chặn tự động (Threat Engine cho điểm 0 + rule chỉ shadow, chặn IP ở edge bỏ qua). Luôn CÓ HẠN (tối đa 90 ngày), lý do
// bắt buộc, passkey + audit. Dùng cho thiết bị duyệt của Google (AS15169, AS396982) trong thời gian duyệt, IP văn phòng...
import { z } from 'zod';
import { chuanHoaDich, SchemaDich, type Dich } from './can-thiep';

export const HAN_CHO_PHEP_MS = { '24h': 86_400_000, '7d': 7 * 86_400_000, '30d': 30 * 86_400_000, '90d': 90 * 86_400_000 } as const;
export type HanChoPhep = keyof typeof HAN_CHO_PHEP_MS;

/** ASN của Google (Play review / pre-launch report trên Firebase Test Lab) - nút điền nhanh ở SOC. */
export const ASN_GOOGLE = ['15169', '396982'] as const;

export const SchemaThemChoPhep = z.strictObject({
  dich: z.array(SchemaDich).min(1).max(10),
  thoiHan: z.enum(Object.keys(HAN_CHO_PHEP_MS) as [HanChoPhep, ...HanChoPhep[]]),
  lyDo: z.string().trim().min(10).max(500),
});
export const SchemaGoChoPhep = z.strictObject({
  id: z.string().regex(/^[0-9A-HJKMNP-TV-Z]{26}$/),
  lyDo: z.string().trim().min(10).max(500),
});

/** Chuẩn hoá + bỏ trùng đích; trả đích hỏng (chỉ số) để báo 400. Dải phải đủ hẹp như khi chặn (/16 - /32). */
export function chuanHoaChoPhep(ds: { loai: Dich['loai']; giaTri: string }[]): { dich: Dich[]; loi: string[] } {
  const thay = new Set<string>();
  const dich: Dich[] = [];
  const loi: string[] = [];
  ds.forEach((d, i) => {
    const c = chuanHoaDich(d);
    if (!c) return void loi.push(`dich.${i}`);
    const k = `${c.loai}:${c.giaTri}`;
    if (!thay.has(k)) {
      thay.add(k);
      dich.push(c);
    }
  });
  return { dich, loi };
}
