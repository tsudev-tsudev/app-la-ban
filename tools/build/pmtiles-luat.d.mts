// Kiểu cho test Worker (workers/api/test/ban-do.test.ts) dùng lại bộ ghi PMTiles của công cụ.
export type Muc = { id: number; chay: number; vt: number; dai: number };
export function dungThuMuc(ds: Muc[]): { goc: Buffer; la: Buffer };
export function ghiHeader(h: Record<string, unknown>): Buffer;
