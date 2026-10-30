// Can thiệp thủ công của SOC (S7b, Spec §8.2-5, QUYET_DINH Q12): chặn / gỡ chặn thiết bị, IP, dải, ASN; thu hồi phiên;
// four-eyes cho thao tác hàng loạt + chặn dải / ASN (trừ khi Under Attack). Hàm thuần: kiểm + chuẩn hoá đầu vào, quyết
// định cần duyệt, TTL. Ghi D1 ở src/threat/can-thiep.ts.
import { z } from 'zod';
import { chuanHoaIp, giaTriDai, phanTichCidr } from './ip';
import { LoiApi } from './loi';
import type { CauHinhNguyCo } from './nguy-co';
import { ttlLeoThang } from './nguy-co';
import type { LoaiDich } from './thuc-thi';

const GIO = 60 * 60_000;
const NGAY = 24 * GIO;

/** Thời hạn chặn người vận hành chọn; 'leo-thang' = theo bậc TTL của cấu hình (24h -> 7d -> 30d -> 365d). */
export const THOI_HAN = { '1h': GIO, '24h': NGAY, '7d': 7 * NGAY, '30d': 30 * NGAY, '365d': 365 * NGAY } as const;
export type ThoiHan = keyof typeof THOI_HAN | 'leo-thang';

/** Hàng loạt tối đa / yêu cầu; yêu cầu four-eyes hết hạn sau 24 giờ. */
export const HANG_LOAT_TOI_DA = 100;
export const YEU_CAU_HAN_MS = NGAY;
/** Dải nhỏ nhất cho phép chặn tay: IPv4 /16, IPv6 /32 (rộng hơn dễ chặn cả nhà mạng). */
const DAI_TOI_THIEU = { 4: 16, 6: 32 } as const;

const LY_DO = z.string().trim().min(10).max(500);

export const SchemaDich = z.strictObject({
  loai: z.enum(['device', 'ip', 'cidr', 'asn']),
  giaTri: z.string().trim().min(1).max(64),
});
export type Dich = { loai: LoaiDich; giaTri: string };

export const SchemaChan = z.strictObject({
  dich: z.array(SchemaDich).min(1).max(HANG_LOAT_TOI_DA),
  /** Thiết bị: ban | restrict; IP / dải / ASN: block. */
  hanhDong: z.enum(['ban', 'restrict', 'block']),
  thoiHan: z.enum(['1h', '24h', '7d', '30d', '365d', 'leo-thang']),
  lyDo: LY_DO,
});
export type YeuCauChan = { dich: Dich[]; hanhDong: 'ban' | 'restrict' | 'block'; thoiHan: ThoiHan; lyDo: string };

export const SchemaGoChan = z.strictObject({
  ids: z.array(z.string().regex(/^[0-9A-Za-z]{20,40}$/)).min(1).max(HANG_LOAT_TOI_DA),
  lyDo: LY_DO,
});
export type YeuCauGoChan = { ids: string[]; lyDo: string };

export const SchemaThuHoiPhien = z.strictObject({
  thietBi: z.string().regex(/^[0-9A-Za-z-]{8,40}$/),
  lyDo: LY_DO,
});

export const SchemaQuyet = z.strictObject({
  id: z.string().regex(/^[0-9A-Za-z]{20,40}$/),
  dongY: z.boolean(),
  ghiChu: z.string().trim().max(500).optional(),
});

export const SchemaHuyYeuCau = z.strictObject({ id: z.string().regex(/^[0-9A-Za-z]{20,40}$/) });

/** Giá trị đích -> dạng chuẩn để so trùng / lưu; sai -> null. */
export function chuanHoaDich(d: { loai: LoaiDich; giaTri: string }): Dich | null {
  const v = d.giaTri.trim();
  switch (d.loai) {
    case 'device':
      return /^[0-9A-Za-z-]{8,40}$/.test(v) ? { loai: 'device', giaTri: v } : null;
    case 'ip': {
      const c = chuanHoaIp(v);
      return c ? { loai: 'ip', giaTri: c } : null;
    }
    case 'cidr': {
      if (!v.includes('/')) return null;
      const dai = phanTichCidr(v);
      if (!dai || dai.doDai < DAI_TOI_THIEU[dai.v]) return null;
      // Dải /32 (/128) là một IP -> lưu dạng ip để khớp middleware + Lists như chặn IP thường.
      if (dai.doDai === (dai.v === 4 ? 32 : 128)) return chuanHoaDich({ loai: 'ip', giaTri: v.slice(0, v.indexOf('/')) });
      return { loai: 'cidr', giaTri: giaTriDai(dai) };
    }
    case 'asn': {
      const so = v.replace(/^AS/i, '');
      return /^\d{1,10}$/.test(so) && Number(so) > 0 && Number(so) < 2 ** 32 ? { loai: 'asn', giaTri: String(Number(so)) } : null;
    }
  }
}

/** Kiểm + chuẩn hoá yêu cầu chặn: đích hợp lệ, không trùng, hành động khớp loại đích. */
export function kiemYeuCauChan(y: z.infer<typeof SchemaChan>): YeuCauChan {
  const loi: string[] = [];
  const thay = new Set<string>();
  const dich: Dich[] = [];
  y.dich.forEach((d, i) => {
    const c = chuanHoaDich(d);
    if (!c) return void loi.push(`dich.${i}`);
    if ((c.loai === 'device') !== (y.hanhDong !== 'block')) return void loi.push(`dich.${i}.hanhDong`);
    const k = `${c.loai}:${c.giaTri}`;
    if (!thay.has(k)) {
      thay.add(k);
      dich.push(c);
    }
  });
  if (loi.length) throw new LoiApi(400, 'dich-loi', loi);
  return { dich, hanhDong: y.hanhDong, thoiHan: y.thoiHan, lyDo: y.lyDo };
}

/**
 * Four-eyes: hàng loạt (> 1 đích) luôn qua yêu cầu chờ duyệt; chặn dải / ASN đơn lẻ là đề xuất chờ duyệt trừ khi Under
 * Attack (giống engine, `canDuyet`). Chặn một thiết bị / một IP có hiệu lực ngay (đã có lý do + step-up + audit).
 */
export function loaiDuyet(y: Pick<YeuCauChan, 'dich'>, underAttack: boolean): 'ngay' | 'de-xuat' | 'yeu-cau' {
  if (y.dich.length > 1) return 'yeu-cau';
  const d = y.dich[0] as Dich;
  return (d.loai === 'cidr' || d.loai === 'asn') && !underAttack ? 'de-xuat' : 'ngay';
}

export function canDuyetGoChan(soId: number): boolean {
  return soId > 1;
}

/** TTL cho một đích: chọn cố định hoặc leo thang theo số lần bị chặn trước (không tính lần bị thu hồi). */
export function ttlCanThiep(cfg: CauHinhNguyCo, thoiHan: ThoiHan, soLanTruoc: number): { bac: number; ttlMs: number } {
  if (thoiHan === 'leo-thang') return ttlLeoThang(cfg, soLanTruoc);
  return { bac: 0, ttlMs: THOI_HAN[thoiHan] };
}

/** Người quyết yêu cầu four-eyes: không phải người tạo, yêu cầu còn chờ và còn hạn. */
export function kiemQuyet(yc: { created_by: string; status: string; expires_at: number }, nguoi: string, bayGio: number): void {
  if (yc.status !== 'pending') throw new LoiApi(409, 'da-quyet');
  if (bayGio >= yc.expires_at) throw new LoiApi(409, 'het-han');
  if (yc.created_by.toLowerCase() === nguoi.toLowerCase()) throw new LoiApi(403, 'khong-tu-duyet');
}

/** Hiển thị đích trong audit / danh sách: IP đơn -> giữ nguyên (người có quyền can thiệp là responder, thấy IP đầy đủ). */
export function moTaDich(d: Dich): string {
  return `${d.loai}:${d.giaTri}`;
}

// ---------------------------------------------------------------- lọc danh sách enforcement
export const SchemaLocThucThi = z.strictObject({
  /** hieu-luc = đang chặn · cho-duyet = đề xuất chờ duyệt · het = hết hạn / thu hồi · tat-ca. */
  trangThai: z.enum(['hieu-luc', 'cho-duyet', 'het', 'tat-ca']).optional(),
  loai: z.enum(['device', 'ip', 'cidr', 'asn']).optional(),
  nguon: z.enum(['auto', 'manual']).optional(),
  q: z.string().regex(/^[0-9A-Za-z.:/-]{1,64}$/).optional(),
  cursor: z.string().max(200).optional(),
  limit: z.string().max(4).optional(),
});
export type LocThucThi = z.infer<typeof SchemaLocThucThi>;

export function docLocThucThi(q: Record<string, string>): LocThucThi {
  const kq = SchemaLocThucThi.safeParse(q);
  if (!kq.success) throw new LoiApi(400, 'loc-loi', kq.error.issues.map((i) => i.path.join('.')));
  return kq.data;
}

/** Điều kiện SQL theo trạng thái (tham số: bayGio cho mọi '?'). */
export function dieuKienTrangThai(tt: LocThucThi['trangThai']): { sql: string; soThamSo: number } | null {
  switch (tt ?? 'hieu-luc') {
    case 'hieu-luc':
      return { sql: 'revoked_at IS NULL AND expires_at > ? AND (pending_approval = 0 OR approved_by IS NOT NULL)', soThamSo: 1 };
    case 'cho-duyet':
      return { sql: 'revoked_at IS NULL AND expires_at > ? AND pending_approval = 1 AND approved_by IS NULL', soThamSo: 1 };
    case 'het':
      return { sql: '(revoked_at IS NOT NULL OR expires_at <= ?)', soThamSo: 1 };
    default:
      return null;
  }
}
