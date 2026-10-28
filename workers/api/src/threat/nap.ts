// Nạp cấu hình điểm, rule, allow-list, danh sách chặn từ D1 - đệm theo isolate (đọc mỗi request quá tốn D1).
// Thay đổi do chính isolate ghi -> gọi xoaDem() để có hiệu lực ngay; isolate khác thấy sau tối đa DEM_MS.
import { ghiLog } from '../mw/ghi-log';
import { CAU_HINH_MAC_DINH, phanTichCauHinh, type CauHinhNguyCo } from '../thuan/nguy-co';
import { phanTichLuat, type DongLuat, type Luat } from '../thuan/luat';
import type { LoaiDich, QuyTac } from '../thuan/thuc-thi';

export const DEM_MS = 15_000;

type Dem<T> = { het: number; giaTri: T } | null;
let demCauHinh: Dem<CauHinhNguyCo> = null;
let demLuat: Dem<Luat[]> = null;
let demChoPhep: Dem<QuyTac[]> = null;
let demChan: Dem<QuyTac[]> = null;

export function xoaDem(): void {
  demCauHinh = demLuat = demChoPhep = demChan = null;
}

async function quaDem<T>(dem: Dem<T>, ghi: (d: Dem<T>) => void, bayGio: number, nap: () => Promise<T>): Promise<T> {
  if (dem && dem.het > bayGio) return dem.giaTri;
  const giaTri = await nap();
  ghi({ het: bayGio + DEM_MS, giaTri });
  return giaTri;
}

export function napCauHinh(db: D1Database, bayGio = Date.now()): Promise<CauHinhNguyCo> {
  return quaDem(demCauHinh, (d) => (demCauHinh = d), bayGio, async () => {
    const d = await db.prepare('SELECT version, config FROM threat_config ORDER BY version DESC LIMIT 1').first<{ version: number; config: string }>();
    if (!d) return CAU_HINH_MAC_DINH;
    const cfg = phanTichCauHinh(d.config);
    if (!cfg) ghiLog('error', 'threat-config-hong', { version: d.version });
    return cfg ?? CAU_HINH_MAC_DINH;
  });
}

export function napLuat(db: D1Database, bayGio = Date.now()): Promise<Luat[]> {
  return quaDem(demLuat, (d) => (demLuat = d), bayGio, async () => {
    const { results } = await db
      .prepare('SELECT id, name, condition, "window", threshold, action, enabled, version, mode, shadow_since FROM rules WHERE enabled = 1')
      .all<DongLuat>();
    return results.flatMap((r) => {
      const l = phanTichLuat(r);
      if (!l) ghiLog('error', 'rule-hong', { id: r.id, version: r.version });
      return l ? [l] : [];
    });
  });
}

type DongQuyTac = { target_type: LoaiDich; target_value: string };
const thanhQuyTac = (ds: DongQuyTac[]): QuyTac[] => ds.map((d) => ({ loai: d.target_type, giaTri: d.target_value }));

export function napChoPhep(db: D1Database, bayGio = Date.now()): Promise<QuyTac[]> {
  return quaDem(demChoPhep, (d) => (demChoPhep = d), bayGio, async () => {
    const { results } = await db
      .prepare('SELECT target_type, target_value FROM allow_list WHERE revoked_at IS NULL AND (expires_at IS NULL OR expires_at > ?)')
      .bind(bayGio)
      .all<DongQuyTac>();
    return thanhQuyTac(results);
  });
}

/** Điều kiện SQL "enforcement mạng còn hiệu lực": chưa thu hồi, chưa hết hạn, không còn chờ duyệt. */
export const SQL_CHAN_HIEU_LUC =
  "action = 'block' AND revoked_at IS NULL AND expires_at > ? AND (pending_approval = 0 OR approved_by IS NOT NULL)";

/** IP / dải / ASN đang bị chặn (chặn thiết bị kiểm ở middleware xác thực S2 qua trạng thái thiết bị). */
export function napChan(db: D1Database, bayGio = Date.now()): Promise<QuyTac[]> {
  return quaDem(demChan, (d) => (demChan = d), bayGio, async () => {
    const { results } = await db
      .prepare(`SELECT target_type, target_value FROM enforcements WHERE target_type IN ('ip', 'cidr', 'asn') AND ${SQL_CHAN_HIEU_LUC}`)
      .bind(bayGio)
      .all<DongQuyTac>();
    return thanhQuyTac(results);
  });
}
