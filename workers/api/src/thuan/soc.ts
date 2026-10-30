// Admin SOC (S6, SEC-ADM, Spec §8.1-8.2): vai trò + quyền, phiên ngắn, che PII theo vai trò, bộ lọc danh sách thiết bị
// -> SQL có tham số. Hàm thuần; Worker chỉ gọi D1 với kết quả ở đây.
import { z } from 'zod';
import { rutGonIp } from './che-pii';
import { giaiMaCursor, docGioiHanTrang, type Cursor } from './cursor';
import { LoiApi } from './loi';

export const VAI_TRO = ['viewer', 'analyst', 'responder', 'security_admin', 'super_admin'] as const;
export type VaiTro = (typeof VAI_TRO)[number];

/** Quyền -> vai trò thấp nhất được làm. Vai trò cao hơn thừa hưởng quyền vai trò thấp hơn. */
export const QUYEN = {
  'tong-quan': 'viewer',
  'thiet-bi:ds': 'viewer',
  'thiet-bi:chi-tiet': 'analyst',
  'pii:ip-day-du': 'analyst',
  'canh-bao:xem': 'viewer',
  'canh-bao:xu-ly': 'analyst',
  // S7b: rule + mô phỏng, can thiệp (chặn / gỡ chặn / thu hồi phiên), duyệt four-eyes, cấu hình điểm + Under Attack.
  'luat:xem': 'analyst',
  'can-thiep': 'responder',
  'luat:sua': 'security_admin',
  'can-thiep:duyet': 'security_admin',
  'cau-hinh-nguy-co': 'security_admin',
  'quan-tri-vien': 'super_admin',
  'cai-dat-soc': 'super_admin',
} as const satisfies Record<string, VaiTro>;
export type Quyen = keyof typeof QUYEN;

export function laVaiTro(s: unknown): s is VaiTro {
  return typeof s === 'string' && (VAI_TRO as readonly string[]).includes(s);
}

export function coQuyen(vaiTro: VaiTro, quyen: Quyen): boolean {
  return VAI_TRO.indexOf(vaiTro) >= VAI_TRO.indexOf(QUYEN[quyen]);
}

export function dsQuyen(vaiTro: VaiTro): Quyen[] {
  return (Object.keys(QUYEN) as Quyen[]).filter((q) => coQuyen(vaiTro, q));
}

// ---------------------------------------------------------------- phiên
export const PHIEN = {
  /** Không thao tác quá lâu -> phải xác thực passkey lại. */
  nhanRoiMs: 15 * 60_000,
  tuyetDoiMs: 8 * 60 * 60_000,
  /** Thao tác nhạy cảm (quản lý quản trị viên, S7: can thiệp) cần passkey trong khoảng này. */
  stepUpMs: 5 * 60_000,
  /** Ghi last_active tối đa mỗi phút một lần (đỡ ghi D1 mỗi request). */
  ghiHoatDongMs: 60_000,
  cookie: '__Host-soc',
} as const;

export type DongPhien = { email: string; created_at: number; last_active: number; step_up_at: number; expires_at: number; revoked_at: number | null };
export type TinhTrangPhien = 'hop-le' | 'thu-hoi' | 'het-han' | 'nhan-roi' | 'sai-danh-tinh';

export function tinhTrangPhien(p: DongPhien, email: string, bayGio: number): TinhTrangPhien {
  if (p.revoked_at !== null) return 'thu-hoi';
  if (p.email.toLowerCase() !== email.toLowerCase()) return 'sai-danh-tinh';
  if (bayGio >= p.expires_at) return 'het-han';
  if (bayGio - p.last_active >= PHIEN.nhanRoiMs) return 'nhan-roi';
  return 'hop-le';
}

export function canGhiHoatDong(p: Pick<DongPhien, 'last_active'>, bayGio: number): boolean {
  return bayGio - p.last_active >= PHIEN.ghiHoatDongMs;
}

export function conStepUp(p: Pick<DongPhien, 'step_up_at'>, bayGio: number): boolean {
  return bayGio - p.step_up_at < PHIEN.stepUpMs;
}

/** Set-Cookie phiên: __Host- (Secure, Path=/, không Domain), HttpOnly, SameSite=Strict; maxAge 0 = xoá. */
export function cookiePhien(giaTri: string, maxAgeGiay: number): string {
  return `${PHIEN.cookie}=${giaTri}; Path=/; Secure; HttpOnly; SameSite=Strict; Max-Age=${Math.max(0, Math.floor(maxAgeGiay))}`;
}

export function docCookie(header: string | null | undefined, ten: string): string | null {
  for (const phan of (header ?? '').split(';')) {
    const [k, ...v] = phan.trim().split('=');
    if (k === ten) {
      const giaTri = v.join('=');
      return /^[A-Za-z0-9_-]{20,100}$/.test(giaTri) ? giaTri : null;
    }
  }
  return null;
}

// ---------------------------------------------------------------- che PII
/** Viewer chỉ thấy dải IP (/24, /48); vai trò từ analyst thấy IP đầy đủ (Spec §8.1 "ẩn bớt PII"). */
export function cheIp(ip: string | null | undefined, vaiTro: VaiTro): string | null {
  if (!ip) return null;
  return coQuyen(vaiTro, 'pii:ip-day-du') ? ip : rutGonIp(ip);
}

// ---------------------------------------------------------------- lọc thiết bị
const TRANG_THAI = ['clean', 'suspicious', 'restricted', 'banned'] as const;
const IPV4 = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
const DAI_V4 = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.0\/24$/;

export const SchemaLocThietBi = z.strictObject({
  trangThai: z.enum(TRANG_THAI).optional(),
  nenTang: z.enum(['android', 'ios']).optional(),
  mucTin: z.string().regex(/^[a-z_-]{1,24}$/).optional(),
  phienBan: z.string().regex(/^[0-9A-Za-z.+_-]{1,32}$/).optional(),
  /** Tiền tố device id (ULID / UUID). */
  q: z.string().regex(/^[0-9A-Za-z-]{2,36}$/).optional(),
  /** IP đầy đủ hoặc dải IPv4 /24. */
  ip: z.string().max(64).optional(),
  asn: z.string().regex(/^\d{1,10}$/).optional(),
  suKien: z.string().regex(/^[A-Z][A-Z0-9_]{1,40}$/).optional(),
  sap: z.enum(['moi-nhat', 'rui-ro']).optional(),
  cursor: z.string().max(200).optional(),
  limit: z.string().max(4).optional(),
});
export type LocThietBi = z.infer<typeof SchemaLocThietBi>;

export const SU_KIEN_CUA_SO_MS = 30 * 24 * 60 * 60_000;

/** Query string -> bộ lọc đã kiểm; khoá lạ / giá trị sai -> 400 `loc-loi`. */
export function docLocThietBi(q: Record<string, string>): LocThietBi {
  const kq = SchemaLocThietBi.safeParse(q);
  if (!kq.success) throw new LoiApi(400, 'loc-loi', kq.error.issues.map((i) => i.path.join('.')));
  const ip = kq.data.ip;
  if (ip !== undefined) {
    const v4 = IPV4.exec(ip) ?? DAI_V4.exec(ip);
    const hopLe = v4 ? v4.slice(1).every((x) => Number(x) <= 255) : /^[0-9a-fA-F:]{2,39}$/.test(ip) && ip.includes(':');
    if (!hopLe) throw new LoiApi(400, 'loc-loi', ['ip']);
  }
  return kq.data;
}

export type TruyVan = { sql: string; thamSo: (string | number)[]; gioiHan: number; cursor: Cursor | null };

const COT_DS =
  'd.id, d.platform, d.model, d.os_version, d.app_version, d.build, d.status, d.risk_score, d.attestation_level, d.country, d.first_seen, d.last_seen,' +
  ' (SELECT i.ip FROM device_ips i WHERE i.device_id = d.id ORDER BY i.last_seen DESC LIMIT 1) AS ip,' +
  ' (SELECT i.asn FROM device_ips i WHERE i.device_id = d.id ORDER BY i.last_seen DESC LIMIT 1) AS asn';

/** Bộ lọc -> SELECT có tham số, phân trang keyset (last_seen | risk_score, id) giảm dần; lấy dư 1 dòng để biết còn trang. */
export function truyVanThietBi(loc: LocThietBi, bayGio: number): TruyVan {
  const dk: string[] = [];
  const ts: (string | number)[] = [];
  const them = (dieuKien: string, ...giaTri: (string | number)[]): void => {
    dk.push(dieuKien);
    ts.push(...giaTri);
  };
  if (loc.trangThai) them('d.status = ?', loc.trangThai);
  if (loc.nenTang) them('d.platform = ?', loc.nenTang);
  if (loc.mucTin) them('d.attestation_level = ?', loc.mucTin);
  if (loc.phienBan) them('d.app_version = ?', loc.phienBan);
  // Schema chỉ cho [0-9A-Za-z-] nên không có ký tự đại diện LIKE (% _) lọt vào.
  if (loc.q) them('d.id LIKE ?', `${loc.q}%`);
  if (loc.ip) {
    const dai = DAI_V4.exec(loc.ip);
    if (dai) them('d.id IN (SELECT device_id FROM device_ips WHERE ip LIKE ?)', `${dai.slice(1, 4).join('.')}.%`);
    else them('d.id IN (SELECT device_id FROM device_ips WHERE ip = ?)', loc.ip);
  }
  if (loc.asn) them('d.id IN (SELECT device_id FROM device_ips WHERE asn = ?)', Number(loc.asn));
  if (loc.suKien) {
    them('d.id IN (SELECT device_id FROM security_events WHERE type = ? AND ts >= ?)', loc.suKien, bayGio - SU_KIEN_CUA_SO_MS);
  }
  const cot = loc.sap === 'rui-ro' ? 'd.risk_score' : 'd.last_seen';
  const cursor = giaiMaCursor(loc.cursor);
  if (cursor) them(`(${cot}, d.id) < (?, ?)`, cursor.t, cursor.id);
  const gioiHan = docGioiHanTrang(loc.limit);
  const where = dk.length ? ` WHERE ${dk.join(' AND ')}` : '';
  return {
    sql: `SELECT ${COT_DS} FROM devices d${where} ORDER BY ${cot} DESC, d.id DESC LIMIT ?`,
    thamSo: [...ts, gioiHan + 1],
    gioiHan,
    cursor,
  };
}

export function giaTriCursor(dong: { last_seen: number; risk_score: number; id: string }, loc: LocThietBi): Cursor {
  return { t: loc.sap === 'rui-ro' ? dong.risk_score : dong.last_seen, id: dong.id };
}

// ---------------------------------------------------------------- cài đặt SOC toàn hệ thống
/**
 * Cài đặt do Super Admin chỉnh, áp cho MỌI người xem SOC (khác tuỳ chọn hiển thị cá nhân lưu ở trình duyệt). Thuỷ vân
 * tắt chỉ bỏ lớp hình răn đe chụp màn hình; mã dấu vết + audit xem dữ liệu ở server vẫn giữ (QUYET_DINH Q41).
 */
export const SchemaCaiDatSoc = z.strictObject({
  thuyVan: z.strictObject({
    bat: z.boolean(),
    /** Độ đậm tối thiểu ép cho mọi người ('nhe' = người xem tự chọn). */
    mucToiThieu: z.enum(['nhe', 'chuan']),
  }),
  /** Ép che dữ liệu khi rời cửa sổ cho mọi người (bật = người xem không tắt được). */
  epCheKhiRoi: z.boolean(),
});
export type CaiDatSoc = z.infer<typeof SchemaCaiDatSoc>;
export const CAI_DAT_SOC_MAC_DINH: CaiDatSoc = { thuyVan: { bat: true, mucToiThieu: 'nhe' }, epCheKhiRoi: false };

/** Dòng D1 soc_settings (key -> JSON) -> cài đặt đầy đủ; khoá thiếu / hỏng lấy mặc định từng phần. */
export function docCaiDatSoc(dong: readonly { key: string; value: string }[]): CaiDatSoc {
  const kq: CaiDatSoc = structuredClone(CAI_DAT_SOC_MAC_DINH);
  for (const d of dong) {
    let v: unknown;
    try {
      v = JSON.parse(d.value);
    } catch {
      continue;
    }
    if (d.key === 'thuyvan') {
      const p = SchemaCaiDatSoc.shape.thuyVan.safeParse(v);
      if (p.success) kq.thuyVan = p.data;
    } else if (d.key === 'epchekhiroi' && typeof v === 'boolean') {
      kq.epCheKhiRoi = v;
    }
  }
  return kq;
}

/** Cài đặt -> các dòng D1 cần ghi (khoá chữ thường, GLOB '[a-z]*' ở migration 0007). */
export function dongCaiDatSoc(c: CaiDatSoc): { key: string; value: string }[] {
  return [
    { key: 'thuyvan', value: JSON.stringify(c.thuyVan) },
    { key: 'epchekhiroi', value: JSON.stringify(c.epCheKhiRoi) },
  ];
}

// ---------------------------------------------------------------- realtime
export type TinSoc = {
  loai: 'su-kien';
  /** Mili giây server nhận lô (đo độ trễ tới màn SOC, ngân sách < 1,5 s). */
  nhanLuc: number;
  thietBi: string | null;
  ip: string | null;
  quocGia: string | null;
  ds: { type: string; severity: string }[];
  kichHoat: string[];
  trangThai: string | null;
};

/** Bản tin gửi cho một vai trò: viewer nhận IP đã rút gọn. */
export function tinChoVaiTro(t: TinSoc, vaiTro: VaiTro): TinSoc {
  return { ...t, ip: cheIp(t.ip, vaiTro) };
}
