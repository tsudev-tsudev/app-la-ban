// Rule engine (IDS) khai báo JSON có cửa sổ thời gian, phiên bản, shadow mode (Spec §7.6d, SEC-DET). Hàm thuần: phân
// tích rule, sinh câu đếm tham số hoá, quyết định kích hoạt. Thực thi (ghi D1) ở src/threat/.
import { z } from 'zod';
import { rutGonIp } from './che-pii';
import type { CauLenh } from './don-dep';
import { MAU_LOAI_SU_KIEN, TUAN_MS } from './nguy-co';

/** Shadow tối thiểu trước khi được bật thực thi. */
export const SHADOW_TOI_THIEU_MS = TUAN_MS;

export const schemaDieuKien = z.strictObject({
  event: z.array(z.string().regex(MAU_LOAI_SU_KIEN)).min(1).max(10),
  group_by: z.enum(['device', 'ip', 'cidr24']),
  /** events = số sự kiện · devices = số thiết bị khác nhau · types = số loại sự kiện khác nhau. */
  count: z.enum(['events', 'devices', 'types']).default('events'),
});
export type DieuKien = z.infer<typeof schemaDieuKien>;

/**
 * Hành động: add_risk_<n> · restrict_device · ban_device · block_ip (IP đơn, TTL leo thang) · propose_cidr_block (chỉ
 * đề xuất - cần duyệt, trừ Under Attack) · alert_<mức>.
 */
const MAU_HANH_DONG = /^(add_risk_([1-9]\d{0,2})|restrict_device|ban_device|block_ip|propose_cidr_block|alert_(low|medium|high|critical))$/;
export const schemaHanhDong = z.array(z.string().regex(MAU_HANH_DONG)).min(1).max(8);

export type Luat = {
  id: string;
  ten: string;
  phienBan: number;
  dieuKien: DieuKien;
  cuaSoMs: number;
  nguong: number;
  hanhDong: string[];
  bat: boolean;
  cheDo: 'shadow' | 'active';
  shadowTu: number | null;
};

export type DongLuat = {
  id: string;
  name: string;
  condition: string;
  window: number;
  threshold: number;
  action: string;
  enabled: number;
  version: number;
  mode: string;
  shadow_since: number | null;
};

/** Dòng D1 -> Luat; rule hỏng trả null (bỏ qua + log, không làm hỏng cả lô). */
export function phanTichLuat(d: DongLuat): Luat | null {
  try {
    const dk = schemaDieuKien.safeParse(JSON.parse(d.condition));
    const hd = schemaHanhDong.safeParse(JSON.parse(d.action));
    if (!dk.success || !hd.success || !(d.window > 0) || !(d.threshold > 0)) return null;
    return {
      id: d.id,
      ten: d.name,
      phienBan: d.version,
      dieuKien: dk.data,
      cuaSoMs: d.window * 1000,
      nguong: d.threshold,
      hanhDong: hd.data,
      bat: d.enabled === 1,
      cheDo: d.mode === 'active' ? 'active' : 'shadow',
      shadowTu: d.shadow_since,
    };
  } catch {
    return null;
  }
}

/** Rule chỉ được chuyển sang active khi đã shadow đủ 7 ngày (Admin S7 gọi trước khi bật). */
export function coTheBatThucThi(l: Pick<Luat, 'cheDo' | 'shadowTu'>, bayGio: number): boolean {
  if (l.cheDo === 'active') return true;
  return l.shadowTu !== null && bayGio - l.shadowTu >= SHADOW_TOI_THIEU_MS;
}

export type NguCanh = { thietBi: string | null; ip: string | null };

/** Khoá nhóm cho [l] với ngữ cảnh sự kiện; null khi thiếu chiều cần gom (vd. rule theo IP mà sự kiện không có IP). */
export function khoaNhom(l: Pick<Luat, 'dieuKien'>, n: NguCanh): string | null {
  switch (l.dieuKien.group_by) {
    case 'device':
      return n.thietBi ? `device:${n.thietBi}` : null;
    case 'ip':
      return n.ip ? `ip:${n.ip}` : null;
    case 'cidr24': {
      const d = rutGonIp(n.ip);
      return d === 'khong-ro' ? null : `cidr24:${d}`;
    }
  }
}

/** Câu đếm trong cửa sổ [bayGio - cuaSo, bayGio] cho nhóm [khoa] (khoa từ khoaNhom). */
export function cauDem(l: Pick<Luat, 'dieuKien' | 'cuaSoMs'>, khoa: string, bayGio: number): CauLenh {
  const { event, count } = l.dieuKien;
  const cot = khoa.startsWith('device:') ? 'device_id' : khoa.startsWith('ip:') ? 'ip' : 'ip_prefix';
  const giaTri = khoa.slice(khoa.indexOf(':') + 1);
  const bieuThuc = count === 'devices' ? 'COUNT(DISTINCT device_id)' : count === 'types' ? 'COUNT(DISTINCT type)' : 'COUNT(*)';
  return {
    sql: `SELECT ${bieuThuc} AS n FROM security_events WHERE ${cot} = ? AND ts > ? AND type IN (${event.map(() => '?').join(', ')})`,
    thamSo: [giaTri, bayGio - l.cuaSoMs, ...event],
  };
}

/** Rule có xét loại sự kiện này không. */
export function luatQuanTam(l: Pick<Luat, 'bat' | 'dieuKien'>, loai: string): boolean {
  return l.bat && l.dieuKien.event.includes(loai);
}

/** Đạt ngưỡng + chưa kích hoạt trong cùng cửa sổ (chống thực thi lặp mỗi sự kiện sau ngưỡng). */
export function nenKichHoat(l: Pick<Luat, 'nguong' | 'cuaSoMs'>, dem: number, lanKichHoatCuoi: number | null, bayGio: number): boolean {
  if (dem < l.nguong) return false;
  return lanKichHoatCuoi === null || bayGio - lanKichHoatCuoi >= l.cuaSoMs;
}

export type HanhDongPhanTich =
  | { loai: 'add_risk'; diem: number }
  | { loai: 'restrict_device' | 'ban_device' | 'block_ip' | 'propose_cidr_block' }
  | { loai: 'alert'; muc: 'low' | 'medium' | 'high' | 'critical' };

export function phanTichHanhDong(h: string): HanhDongPhanTich | null {
  const m = MAU_HANH_DONG.exec(h);
  if (!m) return null;
  if (m[2]) return { loai: 'add_risk', diem: Number(m[2]) };
  if (m[3]) return { loai: 'alert', muc: m[3] as 'low' };
  return { loai: h as 'block_ip' };
}
