// S7c1: khiếu nại từ form landing (Spec §8.2-6, SEC-ADM: "khiếu nại có Turnstile") + xem / kiểm chuỗi audit ở SOC.
// Hàm thuần: kiểm đầu vào, mã REF -> hậu tố id thiết bị, đọc kết quả siteverify của Turnstile, lọc danh sách.
import { z } from 'zod';
import { LoiApi } from './loi';

// ---------------------------------------------------------------- mã REF
const CROCKFORD_KY_TU = /^[0-9A-HJKMNP-TV-Z]{10}$/;

/**
 * Mã REF người dùng gõ lại (màn khoá app: `REF-XXXXX-XXXXX`) -> 10 ký tự cuối id thiết bị. Chấp nhận thiếu tiền tố /
 * gạch / khoảng trắng, chữ thường và các ký tự hay gõ nhầm của Crockford (O -> 0, I / L -> 1). Sai -> null.
 */
export function duoiTuRef(s: string): string | null {
  const gon = s
    .toUpperCase()
    .replace(/^\s*REF/, '')
    .replace(/[\s-]/g, '')
    .replace(/O/g, '0')
    .replace(/[IL]/g, '1');
  return CROCKFORD_KY_TU.test(gon) ? gon : null;
}

// ---------------------------------------------------------------- form công khai
export const KHIEU_NAI_TOI_THIEU = 20;
export const KHIEU_NAI_TOI_DA = 2000;

export const SchemaGuiKhieuNai = z.strictObject({
  ref: z.string().trim().min(10).max(24),
  noiDung: z.string().trim().min(KHIEU_NAI_TOI_THIEU).max(KHIEU_NAI_TOI_DA),
  /** Email để trả lời (tuỳ chọn). Rỗng = không để lại. */
  lienHe: z.union([z.literal(''), z.email().max(254)]).optional(),
  ngonNgu: z.enum(['vi', 'en']),
  turnstile: z.string().min(1).max(2048),
});
export type GuiKhieuNai = z.infer<typeof SchemaGuiKhieuNai>;

/** `action` gắn vào widget Turnstile ở landing; siteverify trả lại để chắc token sinh cho đúng form này. */
export const HANH_DONG_TURNSTILE = 'khieu-nai';

const SchemaSiteverify = z.object({
  success: z.boolean(),
  hostname: z.string().optional(),
  action: z.string().optional(),
  'error-codes': z.array(z.string()).optional(),
});

/**
 * Kết quả `siteverify` -> hợp lệ hay không. [tenMien] rỗng = không kiểm hostname (staging dùng khoá thử của Cloudflare
 * trả `example.com`). Khoá thử cũng không trả `action` nên chỉ kiểm action khi có.
 */
export function kiemTurnstile(kq: unknown, tenMien: readonly string[]): { hopLe: boolean; loi: string[] } {
  const p = SchemaSiteverify.safeParse(kq);
  if (!p.success) return { hopLe: false, loi: ['phan-hoi-loi'] };
  const loi = [...(p.data['error-codes'] ?? [])];
  if (!p.data.success) return { hopLe: false, loi: loi.length ? loi : ['that-bai'] };
  if (tenMien.length && !tenMien.includes(p.data.hostname ?? '')) return { hopLe: false, loi: ['sai-ten-mien'] };
  if (p.data.action && p.data.action !== HANH_DONG_TURNSTILE) return { hopLe: false, loi: ['sai-hanh-dong'] };
  return { hopLe: true, loi: [] };
}

/** Danh sách tên miền dạng "a,b" ở biến môi trường -> mảng (bỏ khoảng trắng / rỗng). */
export function dsTenMien(s: string | undefined): string[] {
  return (s ?? '')
    .split(',')
    .map((x) => x.trim().toLowerCase())
    .filter(Boolean);
}

// ---------------------------------------------------------------- SOC: danh sách + quyết định
export const SchemaLocKhieuNai = z.strictObject({
  trangThai: z.enum(['open', 'approved', 'rejected', 'tat-ca']).optional(),
  cursor: z.string().max(200).optional(),
  limit: z.string().max(4).optional(),
});
export type LocKhieuNai = z.infer<typeof SchemaLocKhieuNai>;

export function docLocKhieuNai(q: Record<string, string>): LocKhieuNai {
  const kq = SchemaLocKhieuNai.safeParse(q);
  if (!kq.success) throw new LoiApi(400, 'loc-loi', kq.error.issues.map((i) => i.path.join('.')));
  return kq.data;
}

export const SchemaQuyetKhieuNai = z.strictObject({
  id: z.string().regex(/^[0-9A-Za-z]{20,40}$/),
  /** chap-nhan: gỡ mọi chặn đang hiệu lực trên thiết bị (enforcement đích device) rồi tính lại trạng thái. */
  quyet: z.enum(['chap-nhan', 'tu-choi']),
  ghiChu: z.string().trim().min(10).max(500),
});
export type QuyetKhieuNai = z.infer<typeof SchemaQuyetKhieuNai>;

// ---------------------------------------------------------------- audit
export const SchemaLocAudit = z.strictObject({
  /** Lọc theo người làm (email chính xác, không phân biệt hoa thường). */
  tacNhan: z.string().trim().min(3).max(254).regex(/^[^%_\s]+$/).optional(),
  /** Tiền tố hành động, vd `can-thiep` hay `can-thiep:chan`. Chỉ [a-z0-9:-] nên không có ký tự đại diện LIKE. */
  hanhDong: z.string().regex(/^[a-z0-9:-]{2,40}$/).optional(),
  /** rowid của dòng cuối trang trước (danh sách giảm dần). */
  truoc: z.string().regex(/^\d{1,15}$/).optional(),
  limit: z.string().max(4).optional(),
});
export type LocAudit = z.infer<typeof SchemaLocAudit>;

export function docLocAudit(q: Record<string, string>): LocAudit {
  const kq = SchemaLocAudit.safeParse(q);
  if (!kq.success) throw new LoiApi(400, 'loc-loi', kq.error.issues.map((i) => i.path.join('.')));
  return kq.data;
}

/** Bộ lọc -> WHERE có tham số cho `audit_logs` (keyset theo rowid giảm dần). */
export function truyVanAudit(loc: LocAudit): { where: string; thamSo: (string | number)[] } {
  const dk: string[] = [];
  const ts: (string | number)[] = [];
  if (loc.tacNhan) {
    dk.push('actor = ? COLLATE NOCASE');
    ts.push(loc.tacNhan);
  }
  if (loc.hanhDong) {
    dk.push('(action = ? OR action LIKE ?)');
    ts.push(loc.hanhDong, `${loc.hanhDong}${loc.hanhDong.endsWith(':') ? '' : ':'}%`);
  }
  if (loc.truoc) {
    dk.push('rowid < ?');
    ts.push(Number(loc.truoc));
  }
  return { where: dk.length ? ` WHERE ${dk.join(' AND ')}` : '', thamSo: ts };
}

/** Kiểm chuỗi theo lô (D1 trả tối đa vài nghìn dòng / truy vấn): số dòng mỗi lô. */
export const LO_KIEM_AUDIT = 2000;
