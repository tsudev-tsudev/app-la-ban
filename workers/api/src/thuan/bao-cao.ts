// S7c2 (Spec §8.2-8) - báo cáo SOC: CSV "có kiểm soát" (quyền + passkey + audit mỗi lần xuất, che PII theo vai trò ở
// server, chặn công thức bảng tính, trần số dòng) + khoảng thời gian cho trang tổng hợp in PDF bằng trình duyệt.
import { z } from 'zod';
import { rutGonIp } from './che-pii';
import { coQuyen, type VaiTro } from './soc';

export const LOAI_BAO_CAO = ['thiet-bi', 'su-kien', 'thuc-thi', 'khieu-nai'] as const;
export type LoaiBaoCao = (typeof LOAI_BAO_CAO)[number];
export const DONG_TOI_DA = 10_000;
export const KHOANG_TOI_DA_MS = 92 * 86_400_000;
/** Giờ Việt Nam (UTC+7, không đổi giờ mùa hè) - ngày trong báo cáo theo giờ VN. */
export const LECH_VN_MS = 7 * 3_600_000;

export const SchemaXuat = z.strictObject({
  loai: z.enum(LOAI_BAO_CAO),
  tu: z.number().int().min(0),
  den: z.number().int().min(0),
});

export type Khoang = { tu: number; den: number };

/** Khoảng [tu, den) hợp lệ: tu < den, không quá 92 ngày, den không quá xa tương lai. */
export function kiemKhoang(tu: number, den: number, bayGio: number): Khoang | null {
  if (!(Number.isInteger(tu) && Number.isInteger(den)) || tu >= den || den - tu > KHOANG_TOI_DA_MS || den > bayGio + 86_400_000) return null;
  return { tu, den };
}

/** Query `?tu=&den=` (ms) của trang tổng hợp; thiếu -> 7 ngày gần nhất. */
export function docKhoang(q: Record<string, string>, bayGio: number): Khoang | null {
  const so = (s: string | undefined) => (s && /^\d{1,15}$/.test(s) ? Number(s) : null);
  const den = so(q.den) ?? bayGio;
  const tu = so(q.tu) ?? den - 7 * 86_400_000;
  return kiemKhoang(tu, den, bayGio);
}

/** Thời điểm ms -> "YYYY-MM-DD HH:mm:ss" giờ VN (Excel đọc được thành ngày giờ, không phụ thuộc múi giờ máy mở). */
export function gioVn(ms: number | null | undefined): string {
  if (ms === null || ms === undefined) return '';
  return new Date(ms + LECH_VN_MS).toISOString().slice(0, 19).replace('T', ' ');
}

/** Ngày VN (YYYY-MM-DD) - nhóm theo ngày cho biểu đồ tổng hợp. */
export function ngayVn(ms: number): string {
  return new Date(ms + LECH_VN_MS).toISOString().slice(0, 10);
}

/**
 * Một ô CSV: chuỗi bắt đầu bằng = + - @ TAB CR bị thêm dấu ' (chống CSV injection / DDE khi mở bằng Excel, OWASP);
 * số giữ nguyên (số âm hợp lệ). Bọc nháy kép khi có , " CR LF.
 */
export function oCsv(v: unknown): string {
  if (v === null || v === undefined) return '';
  if (typeof v === 'number') return Number.isFinite(v) ? String(v) : '';
  if (typeof v === 'boolean') return v ? '1' : '0';
  let s = String(v);
  if (/^[=+\-@\t\r]/.test(s)) s = `'${s}`;
  return /[",\r\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

/** Bảng -> CSV UTF-8 có BOM (Excel nhận tiếng Việt), dòng CRLF (RFC 4180). */
export function taoCsv(cot: readonly string[], dong: readonly (readonly unknown[])[]): string {
  return `\uFEFF${[cot, ...dong].map((d) => d.map(oCsv).join(',')).join('\r\n')}\r\n`;
}

/** Email liên hệ khiếu nại: chỉ Security Admin trở lên xuất nguyên văn; còn lại giữ ký tự đầu + tên miền. */
export function cheEmail(e: string | null | undefined, vaiTro: VaiTro): string {
  if (!e) return '';
  if (coQuyen(vaiTro, 'bao-cao:lien-he')) return e;
  const at = e.lastIndexOf('@');
  return at > 0 ? `${e[0]}***${e.slice(at)}` : '***';
}

const cheIpBc = (ip: string | null | undefined, vaiTro: VaiTro) => (!ip ? '' : coQuyen(vaiTro, 'pii:ip-day-du') ? ip : rutGonIp(ip));

type Dinh = { cot: readonly string[]; sql: string; dong: (r: Record<string, unknown>, vt: VaiTro) => unknown[] };

/** Cột + truy vấn (đã có LIMIT ? - tham số: tu, den, DONG_TOI_DA + 1) + ánh xạ có che PII cho từng loại. */
export const DINH_NGHIA: Readonly<Record<LoaiBaoCao, Dinh>> = {
  'thiet-bi': {
    cot: ['id', 'nen_tang', 'he_dieu_hanh', 'model', 'phien_ban_app', 'build', 'trang_thai', 'diem_rui_ro', 'muc_tin', 'quoc_gia', 'lan_dau', 'lan_cuoi'],
    sql: 'SELECT id, platform, os_version, model, app_version, build, status, risk_score, attestation_level, country, first_seen, last_seen FROM devices WHERE last_seen >= ? AND last_seen < ? ORDER BY last_seen DESC LIMIT ?',
    dong: (r) => [r.id, r.platform, r.os_version, r.model, r.app_version, r.build, r.status, r.risk_score, r.attestation_level, r.country, gioVn(r.first_seen as number), gioVn(r.last_seen as number)],
  },
  'su-kien': {
    cot: ['id', 'thoi_diem', 'thiet_bi', 'loai', 'muc_do', 'rule', 'diem_cong', 'ip'],
    sql: 'SELECT id, ts, device_id, type, severity, rule_id, risk_delta, ip FROM security_events WHERE ts >= ? AND ts < ? ORDER BY ts DESC LIMIT ?',
    dong: (r, vt) => [r.id, gioVn(r.ts as number), r.device_id, r.type, r.severity, r.rule_id, r.risk_delta, cheIpBc(r.ip as string | null, vt)],
  },
  'thuc-thi': {
    cot: ['id', 'tao_luc', 'loai_dich', 'dich', 'hanh_dong', 'ly_do', 'nguon', 'rule', 'tao_boi', 'duyet_boi', 'cho_duyet', 'het_han', 'thu_hoi_luc'],
    sql: 'SELECT id, created_at, target_type, target_value, action, reason, source, rule_id, created_by, approved_by, pending_approval, expires_at, revoked_at FROM enforcements WHERE created_at >= ? AND created_at < ? ORDER BY created_at DESC LIMIT ?',
    dong: (r, vt) => [
      r.id,
      gioVn(r.created_at as number),
      r.target_type,
      r.target_type === 'ip' ? cheIpBc(r.target_value as string, vt) : r.target_value,
      r.action,
      r.reason,
      r.source,
      r.rule_id,
      r.created_by,
      r.approved_by,
      r.pending_approval,
      gioVn(r.expires_at as number),
      gioVn(r.revoked_at as number | null),
    ],
  },
  'khieu-nai': {
    cot: ['id', 'thoi_diem', 'thiet_bi', 'trang_thai', 'chan_lien_quan', 'ngon_ngu', 'lien_he', 'noi_dung', 'xu_ly_boi', 'xu_ly_luc', 'ghi_chu_quyet_dinh'],
    sql: 'SELECT id, ts, device_id, status, enforcement_id, lang, contact, message, reviewed_by, reviewed_at, decision_note FROM appeals WHERE ts >= ? AND ts < ? ORDER BY ts DESC LIMIT ?',
    dong: (r, vt) => [
      r.id,
      gioVn(r.ts as number),
      r.device_id,
      r.status,
      r.enforcement_id,
      r.lang,
      cheEmail(r.contact as string | null, vt),
      r.message,
      r.reviewed_by,
      gioVn(r.reviewed_at as number | null),
      r.decision_note,
    ],
  },
};

/** Tên tệp tải về: la-ban-<loai>-<ngày VN từ>_<ngày VN đến>.csv (chỉ ASCII). */
export function tenTep(loai: LoaiBaoCao, k: Khoang): string {
  return `la-ban-${loai}-${ngayVn(k.tu)}_${ngayVn(k.den - 1)}.csv`;
}

/** Điền đủ các ngày trong khoảng (ngày không có sự kiện = 0) cho biểu đồ cột theo ngày. */
export function dayNgay(k: Khoang, ds: readonly { k: string; n: number }[]): { k: string; n: number }[] {
  const theo = new Map(ds.map((x) => [x.k, x.n]));
  const kq: { k: string; n: number }[] = [];
  for (let t = Date.parse(`${ngayVn(k.tu)}T00:00:00Z`); kq.length < 100; t += 86_400_000) {
    const ngay = new Date(t).toISOString().slice(0, 10);
    if (ngay > ngayVn(k.den - 1)) break;
    kq.push({ k: ngay, n: theo.get(ngay) ?? 0 });
  }
  return kq;
}
