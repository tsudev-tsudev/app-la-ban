// S9 (SEC-WEB-SHIELD): phần thuần cho lớp khiên web - gói cấu hình ký số đặt ở KV và tín hiệu công cụ nhà phát triển
// từ landing / admin. Tín hiệu web chỉ là TÍN HIỆU (Threat Engine ghi theo IP, không quyết định chặn từ trình duyệt).
import { z } from 'zod';

/** Khoá KV `CAU_HINH` chứa gói đã ký (tools/cau-hinh/ky-cau-hinh.mjs dua-len). */
export const KHOA_KV_KHIEN = 'web-khien';

const B64URL = /^[A-Za-z0-9_-]+$/;

const schemaGoi = (toiDa: number) =>
  z.strictObject({
    kid: z.string().min(1).max(32),
    duLieu: z.string().min(1).max(toiDa).regex(B64URL),
    chuKy: z.string().min(1).max(128).regex(B64URL),
  });

/**
 * Gói trong KV -> chuỗi JSON để phục vụ nguyên văn, hoặc null nếu sai hình dạng. Worker KHÔNG kiểm chữ ký (không giữ khoá):
 * trình duyệt kiểm bằng khoá công khai nhúng sẵn, nên KV bị ghi bậy cũng chỉ làm trang về mức `chat`.
 */
export function goiCauHinhHopLe(raw: string | null, duLieuToiDa = 4096): string | null {
  if (!raw || raw.length > duLieuToiDa + 4096) return null;
  try {
    const kq = schemaGoi(duLieuToiDa).safeParse(JSON.parse(raw));
    return kq.success ? JSON.stringify(kq.data) : null;
  } catch {
    return null;
  }
}

export const schemaTinHieuWeb = z.strictObject({
  trang: z.enum(['landing', 'admin']),
  loai: z.enum(['devtools']),
  duongDan: z.string().max(128).regex(/^\/[A-Za-z0-9/._-]*$/),
  tinHieu: z.strictObject({
    kich_thuoc: z.boolean(),
    diem: z.number().int().min(0).max(1000),
    phim: z.number().int().min(0).max(10_000),
    menu: z.number().int().min(0).max(10_000),
  }),
});
export type TinHieuWeb = z.infer<typeof schemaTinHieuWeb>;

export const LOAI_SU_KIEN_WEB = 'WEB_DEVTOOLS';

/** Tín hiệu web -> sự kiện Threat Engine (theo IP, severity low). Đường dẫn trang là của site mình, không phải PII. */
export function suKienTuTinHieu(t: TinHieuWeb, id: string): { id: string; type: string; severity: string; signals: Record<string, unknown> } {
  return {
    id,
    type: LOAI_SU_KIEN_WEB,
    severity: 'low',
    signals: { trang: t.trang, duong_dan: t.duongDan, ...t.tinHieu },
  };
}
