// Phân trang cursor (Spec §6.3): cursor = base64url của {t, id} bản ghi cuối trang; ổn định khi có bản ghi mới chen vào.
import { z } from 'zod';
import { LoiApi } from './loi';

const SchemaCursor = z.strictObject({ t: z.number().int().nonnegative(), id: z.string().min(1).max(64) });
export type Cursor = z.infer<typeof SchemaCursor>;

export const TRANG_MAC_DINH = 50;
export const TRANG_TOI_DA = 200;

function base64url(s: string): string {
  const b = new TextEncoder().encode(s);
  let nhiPhan = '';
  for (const x of b) nhiPhan += String.fromCharCode(x);
  return btoa(nhiPhan).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export function maHoaCursor(c: Cursor): string {
  return base64url(JSON.stringify({ t: c.t, id: c.id }));
}

/** null / rỗng -> null (trang đầu). Sai định dạng -> 400 `cursor-loi`. */
export function giaiMaCursor(s: string | null | undefined): Cursor | null {
  if (!s) return null;
  if (s.length > 200 || !/^[A-Za-z0-9_-]+$/.test(s)) throw new LoiApi(400, 'cursor-loi');
  try {
    const nhiPhan = atob(s.replace(/-/g, '+').replace(/_/g, '/'));
    const json = new TextDecoder().decode(Uint8Array.from(nhiPhan, (c) => c.charCodeAt(0)));
    return SchemaCursor.parse(JSON.parse(json));
  } catch {
    throw new LoiApi(400, 'cursor-loi');
  }
}

/** Đọc `limit` từ query: mặc định 50, kẹp 1..200; không phải số nguyên -> 400. */
export function docGioiHanTrang(s: string | null | undefined): number {
  if (s === null || s === undefined || s === '') return TRANG_MAC_DINH;
  if (!/^\d{1,4}$/.test(s)) throw new LoiApi(400, 'limit-loi');
  return Math.min(TRANG_TOI_DA, Math.max(1, Number(s)));
}

/**
 * Truy vấn lấy `limit + 1` dòng (sắp giảm dần theo t, id); hàm cắt về `limit` và trả cursor trang sau nếu còn.
 */
export function catTrang<T>(dong: T[], limit: number, khoa: (d: T) => Cursor): { items: T[]; nextCursor: string | null } {
  if (dong.length <= limit) return { items: dong, nextCursor: null };
  const items = dong.slice(0, limit);
  const cuoi = items[items.length - 1];
  return { items, nextCursor: cuoi === undefined ? null : maHoaCursor(khoa(cuoi)) };
}
