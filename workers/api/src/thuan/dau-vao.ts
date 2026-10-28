// SEC-API API-02: đọc body JSON có giới hạn kích thước / độ sâu, schema zod CHẶT (trường lạ -> lỗi).
import { z } from 'zod';
import { LoiApi } from './loi';

export const BODY_TOI_DA = 16 * 1024;
export const DO_SAU_TOI_DA = 8;

/** Độ sâu lồng của giá trị JSON (vô hướng = 0, `{}` / `[]` = 1). Dừng sớm khi vượt [tran]. */
export function doSau(giaTri: unknown, tran = DO_SAU_TOI_DA + 1): number {
  if (giaTri === null || typeof giaTri !== 'object') return 0;
  if (tran <= 0) return 1;
  let sauNhat = 0;
  for (const con of Object.values(giaTri as Record<string, unknown>)) {
    sauNhat = Math.max(sauNhat, doSau(con, tran - 1));
    if (sauNhat >= tran) break;
  }
  return 1 + sauNhat;
}

/** Kiểm loại nội dung là JSON (cho phép tham số charset). */
export function laJson(contentType: string | null | undefined): boolean {
  if (!contentType) return false;
  const loai = contentType.split(';')[0]?.trim().toLowerCase();
  return loai === 'application/json';
}

/**
 * Văn bản body -> dữ liệu đã kiểm theo [schema]. Ném [LoiApi]:
 * 413 `qua-lon`, 400 `json-loi`, 400 `qua-sau`, 422 `sai-du-lieu` (chi tiết zod chỉ ở `chiTiet` để ghi log).
 */
export function phanTichBody<T extends z.ZodType>(
  vanBan: string,
  schema: T,
  { toiDa = BODY_TOI_DA, sauToiDa = DO_SAU_TOI_DA }: { toiDa?: number; sauToiDa?: number } = {},
): z.infer<T> {
  if (new TextEncoder().encode(vanBan).byteLength > toiDa) throw new LoiApi(413, 'qua-lon');
  let du: unknown;
  try {
    du = JSON.parse(vanBan);
  } catch {
    throw new LoiApi(400, 'json-loi');
  }
  if (doSau(du, sauToiDa + 1) > sauToiDa) throw new LoiApi(400, 'qua-sau');
  const kq = schema.safeParse(du);
  if (!kq.success) {
    throw new LoiApi(
      422,
      'sai-du-lieu',
      kq.error.issues.map((i) => ({ path: i.path.join('.'), code: i.code })),
    );
  }
  return kq.data;
}
