// Trung tâm cảnh báo SOC (S7a, Spec §8.2 mục 3): bộ lọc -> SQL có tham số, vòng đời open -> ack -> closed, thao tác hàng
// loạt, che khoá nhóm theo vai trò, nội dung Telegram KHÔNG chứa PII. Hàm thuần; Worker chỉ gọi D1 / fetch với kết quả.
import { z } from 'zod';
import { rutGonIp } from './che-pii';
import { docGioiHanTrang, giaiMaCursor, type Cursor } from './cursor';
import { LoiApi } from './loi';
import { cheIp, type VaiTro } from './soc';

export const TRANG_THAI_CB = ['open', 'ack', 'closed'] as const;
export type TrangThaiCb = (typeof TRANG_THAI_CB)[number];
export const KET_LUAN = ['true_positive', 'false_positive', 'benign'] as const;
export const MUC_DO = ['low', 'medium', 'high', 'critical'] as const;

const EMAIL = /^[^\s@]{1,64}@[^\s@]{1,190}$/;

// ---------------------------------------------------------------- khoá nhóm
/** `ip:<ip>` -> viewer chỉ thấy dải; `device:` / `cidr24:` giữ nguyên (không phải PII trực tiếp). */
export function cheKhoaNhom(khoa: string, vaiTro: VaiTro): string {
  if (khoa.startsWith('ip:')) return `ip:${cheIp(khoa.slice(3), vaiTro) ?? ''}`;
  return khoa;
}

/** Khoá nhóm -> liên kết điều hướng trong SOC (thiết bị / lọc theo IP). */
export function dichKhoaNhom(khoa: string): { loai: 'device' | 'ip' | 'cidr' | 'khac'; giaTri: string } {
  const i = khoa.indexOf(':');
  const giaTri = i < 0 ? khoa : khoa.slice(i + 1);
  if (khoa.startsWith('device:')) return { loai: 'device', giaTri };
  if (khoa.startsWith('ip:')) return { loai: 'ip', giaTri };
  if (khoa.startsWith('cidr24:')) return { loai: 'cidr', giaTri };
  return { loai: 'khac', giaTri: khoa };
}

// ---------------------------------------------------------------- lọc
export const SchemaLocCanhBao = z.strictObject({
  /** 'hoat-dong' = open + ack (mặc định), 'tat-ca' = mọi trạng thái. */
  trangThai: z.enum(['hoat-dong', 'tat-ca', ...TRANG_THAI_CB]).optional(),
  mucDo: z.enum(MUC_DO).optional(),
  rule: z.string().regex(/^[A-Za-z0-9_-]{1,40}$/).optional(),
  /** 'toi' | 'chua' (chưa phân công) | email. */
  nguoi: z.string().max(260).optional(),
  /** 'an' ẩn shadow, 'chi' chỉ shadow. */
  shadow: z.enum(['an', 'chi']).optional(),
  /** Tiền tố khoá nhóm sau dấu ':' (device id / IP / dải). */
  q: z.string().regex(/^[0-9A-Za-z.:/-]{2,64}$/).optional(),
  cursor: z.string().max(200).optional(),
  limit: z.string().max(4).optional(),
});
export type LocCanhBao = z.infer<typeof SchemaLocCanhBao>;

export function docLocCanhBao(q: Record<string, string>): LocCanhBao {
  const kq = SchemaLocCanhBao.safeParse(q);
  if (!kq.success) throw new LoiApi(400, 'loc-loi', kq.error.issues.map((i) => i.path.join('.')));
  const n = kq.data.nguoi;
  if (n !== undefined && n !== 'toi' && n !== 'chua' && !EMAIL.test(n)) throw new LoiApi(400, 'loc-loi', ['nguoi']);
  return kq.data;
}

export type TruyVanCb = { sql: string; thamSo: (string | number)[]; gioiHan: number; cursor: Cursor | null };

const COT_CB =
  'a.id, a.rule_id, r.name AS rule_name, a.severity, a.group_key, a.count, a.shadow, a.first_ts, a.last_ts, a.status, a.assignee, a.resolution, a.updated_at, a.updated_by';

/** Bộ lọc -> SELECT keyset (last_ts, id) giảm dần; lấy dư 1 dòng để biết còn trang. */
export function truyVanCanhBao(loc: LocCanhBao, email: string): TruyVanCb {
  const dk: string[] = [];
  const ts: (string | number)[] = [];
  const them = (d: string, ...v: (string | number)[]): void => {
    dk.push(d);
    ts.push(...v);
  };
  const tt = loc.trangThai ?? 'hoat-dong';
  if (tt === 'hoat-dong') dk.push("a.status IN ('open', 'ack')");
  else if (tt !== 'tat-ca') them('a.status = ?', tt);
  if (loc.mucDo) them('a.severity = ?', loc.mucDo);
  if (loc.rule) them('a.rule_id = ?', loc.rule);
  if (loc.nguoi === 'toi') them('a.assignee = ?', email);
  else if (loc.nguoi === 'chua') dk.push('a.assignee IS NULL');
  else if (loc.nguoi) them('a.assignee = ?', loc.nguoi);
  if (loc.shadow === 'an') dk.push('a.shadow = 0');
  else if (loc.shadow === 'chi') dk.push('a.shadow = 1');
  // Schema không cho % _ nên không có ký tự đại diện LIKE lọt vào.
  if (loc.q) them("substr(a.group_key, instr(a.group_key, ':') + 1) LIKE ?", `${loc.q}%`);
  const cursor = giaiMaCursor(loc.cursor);
  if (cursor) them('(a.last_ts, a.id) < (?, ?)', cursor.t, cursor.id);
  const gioiHan = docGioiHanTrang(loc.limit);
  const where = dk.length ? ` WHERE ${dk.join(' AND ')}` : '';
  return {
    sql: `SELECT ${COT_CB} FROM alerts a LEFT JOIN rules r ON r.id = a.rule_id${where} ORDER BY a.last_ts DESC, a.id DESC LIMIT ?`,
    thamSo: [...ts, gioiHan + 1],
    gioiHan,
    cursor,
  };
}

// ---------------------------------------------------------------- thao tác
export const HANH_DONG_CB = ['nhan', 'ack', 'dong', 'mo-lai', 'phan-cong', 'ghi-chu'] as const;
export type HanhDongCb = (typeof HANH_DONG_CB)[number];
/** Trần thao tác hàng loạt mỗi lần (giao diện chọn theo trang). */
export const LO_TOI_DA = 100;

export const SchemaThaoTac = z
  .strictObject({
    ids: z
      .array(z.string().regex(/^[0-9A-Za-z-]{8,40}$/))
      .min(1)
      .max(LO_TOI_DA),
    hanhDong: z.enum(HANH_DONG_CB),
    ketLuan: z.enum(KET_LUAN).optional(),
    /** Phân công: email người nhận, null = bỏ phân công. */
    nguoi: z.string().trim().toLowerCase().regex(EMAIL).nullable().optional(),
    ghiChu: z.string().trim().min(1).max(2000).optional(),
  })
  .superRefine((b, ctx) => {
    if (new Set(b.ids).size !== b.ids.length) ctx.addIssue({ code: 'custom', path: ['ids'], message: 'trung' });
    if (b.hanhDong === 'dong' && !b.ketLuan) ctx.addIssue({ code: 'custom', path: ['ketLuan'], message: 'bat-buoc' });
    if (b.hanhDong === 'phan-cong' && b.nguoi === undefined) ctx.addIssue({ code: 'custom', path: ['nguoi'], message: 'bat-buoc' });
    if (b.hanhDong === 'ghi-chu' && (!b.ghiChu || b.ids.length !== 1)) ctx.addIssue({ code: 'custom', path: ['ghiChu'], message: 'bat-buoc' });
  });
export type ThaoTac = z.infer<typeof SchemaThaoTac>;

export type DongCb = { id: string; status: TrangThaiCb; assignee: string | null; resolution: string | null };
export type ThayDoiCb = {
  id: string;
  status: TrangThaiCb;
  assignee: string | null;
  resolution: string | null;
  /** Dòng thời gian: kind + nội dung ngắn (mã máy - giao diện dịch). */
  ghi: { kind: 'note' | 'status' | 'assign'; body: string }[];
};

/**
 * Áp một thao tác lên một cảnh báo. null = không áp được (sai trạng thái) -> bỏ qua dòng đó trong lô, báo lại số bỏ qua.
 * 'nhan' = tự nhận (phân công cho mình, open -> ack). 'mo-lai' xoá kết luận cũ.
 */
export function apThaoTac(d: DongCb, tt: ThaoTac, email: string): ThayDoiCb | null {
  const moi: ThayDoiCb = { id: d.id, status: d.status, assignee: d.assignee, resolution: d.resolution, ghi: [] };
  const doiTrangThai = (s: TrangThaiCb, them = '') => {
    moi.ghi.push({ kind: 'status', body: `${d.status}>${s}${them}` });
    moi.status = s;
  };
  const doiNguoi = (n: string | null) => {
    if (n === d.assignee) return;
    moi.ghi.push({ kind: 'assign', body: n ?? '-' });
    moi.assignee = n;
  };
  switch (tt.hanhDong) {
    case 'nhan':
      if (d.status === 'closed') return null;
      doiNguoi(email);
      if (d.status === 'open') doiTrangThai('ack');
      break;
    case 'ack':
      if (d.status !== 'open') return null;
      doiTrangThai('ack');
      break;
    case 'dong':
      if (d.status === 'closed') return null;
      doiTrangThai('closed', `:${tt.ketLuan}`);
      moi.resolution = tt.ketLuan ?? null;
      break;
    case 'mo-lai':
      if (d.status !== 'closed') return null;
      doiTrangThai('open');
      moi.resolution = null;
      break;
    case 'phan-cong':
      if (d.status === 'closed') return null;
      doiNguoi(tt.nguoi ?? null);
      break;
    case 'ghi-chu':
      moi.ghi.push({ kind: 'note', body: tt.ghiChu ?? '' });
      break;
  }
  if (tt.ghiChu && tt.hanhDong !== 'ghi-chu') moi.ghi.push({ kind: 'note', body: tt.ghiChu });
  return moi.ghi.length ? moi : null;
}

// ---------------------------------------------------------------- Telegram
export const MUC_TELEGRAM = ['high', 'critical'] as const;

/** Chỉ báo khi cảnh báo THẬT (không shadow), mức cao trở lên, chưa từng báo. */
export function canBaoTelegram(a: { severity: string; shadow: number; notified_at: number | null }): boolean {
  return a.shadow === 0 && a.notified_at === null && (MUC_TELEGRAM as readonly string[]).includes(a.severity);
}

/** Khoá nhóm cho kênh ngoài: IP -> dải, device id -> 8 ký tự đầu (đủ tra trong SOC, không lộ định danh đầy đủ). */
export function khoaNhomNgoai(khoa: string): string {
  const { loai, giaTri } = dichKhoaNhom(khoa);
  if (loai === 'ip') return `ip:${rutGonIp(giaTri)}`;
  if (loai === 'device') return `device:${giaTri.slice(0, 8)}…`;
  return khoa.slice(0, 64);
}

const MUC_BIEU_TUONG: Record<string, string> = { critical: '🔴', high: '🟠', medium: '🟡', low: '⚪' };

/** Tin nhắn văn bản thuần (không parse_mode -> không cần thoát ký tự Markdown / HTML). */
export function noiDungTelegram(a: { id: string; rule_id: string; rule_name: string | null; severity: string; group_key: string; count: number }, moiTruong: string, goc: string): string {
  return [
    `${MUC_BIEU_TUONG[a.severity] ?? '•'} [${moiTruong}] ${a.severity.toUpperCase()} · ${a.rule_id}${a.rule_name ? ` ${a.rule_name.slice(0, 80)}` : ''}`,
    `Nhóm: ${khoaNhomNgoai(a.group_key)} · ${a.count} lần`,
    `${goc}/#/canh-bao/${a.id}`,
  ].join('\n');
}
