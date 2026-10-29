// Bảng điểm rủi ro + ngưỡng trạng thái + hồi phục uy tín + leo thang TTL (Spec §7.6c, SEC-DET). Hàm thuần.
import { z } from 'zod';

const GIO = 60 * 60 * 1000;
const NGAY = 24 * GIO;
export const TUAN_MS = 7 * NGAY;

export const TRANG_THAI = ['clean', 'suspicious', 'restricted', 'banned'] as const;
export type TrangThai = (typeof TRANG_THAI)[number];

/** Mã loại sự kiện: CHỮ_HOA_GẠCH_DƯỚI. Loại không có trong bảng điểm vẫn được lưu, điểm 0. */
export const MAU_LOAI_SU_KIEN = /^[A-Z][A-Z0-9_]{2,47}$/;

const soNguyen = (min: number, max: number) => z.number().int().min(min).max(max);

export const schemaCauHinh = z.strictObject({
  diem: z.record(z.string().regex(MAU_LOAI_SU_KIEN), soNguyen(0, 1000)),
  nguong: z.strictObject({ suspicious: soNguyen(1, 10_000), restricted: soNguyen(1, 10_000), banned: soNguyen(1, 10_000) }),
  hoiPhuc: z.strictObject({ diemMoiTuan: soNguyen(0, 1000), san: soNguyen(0, 10_000) }),
  /** Bậc TTL chặn đơn lẻ theo số lần tái phạm (ms). Bậc cuối lặp lại - mọi chặn đều có hạn (QUYET_DINH Q12). */
  ttlBac: z.array(soNguyen(60_000, 400 * NGAY)).min(1).max(8),
  /** Chế độ Under Attack do người vận hành bật: đề xuất chặn dải có hiệu lực ngay, không chờ duyệt. */
  underAttack: z.boolean(),
  /** Điểm tối đa (chặn tràn). */
  diemToiDa: soNguyen(100, 100_000),
}).refine((c) => c.nguong.suspicious < c.nguong.restricted && c.nguong.restricted < c.nguong.banned, {
  message: 'ngưỡng phải tăng dần',
});

export type CauHinhNguyCo = z.infer<typeof schemaCauHinh>;

export const CAU_HINH_MAC_DINH: CauHinhNguyCo = Object.freeze({
  diem: Object.freeze({
    ATTEST_FAIL: 60,
    APP_REPACKAGED: 60,
    HOOK_FRIDA: 50,
    HOOK_XPOSED: 50,
    ROOT: 25,
    JAILBREAK: 25,
    EMULATOR: 30,
    DEBUGGER_ATTACHED: 30,
    MOCK_LOCATION: 20,
    PROXY: 15,
    USER_CA: 15,
    SIGNATURE_MISMATCH: 40,
    RATE_ABUSE: 20,
    MULTI_ACCOUNT_SAME_IP: 10,
    HONEYPOT_HIT: 15,
    WEB_DEVTOOLS: 5,
  }),
  nguong: Object.freeze({ suspicious: 30, restricted: 60, banned: 90 }),
  hoiPhuc: Object.freeze({ diemMoiTuan: 5, san: 0 }),
  ttlBac: Object.freeze([NGAY, 7 * NGAY, 30 * NGAY, 365 * NGAY]) as number[],
  underAttack: false,
  diemToiDa: 1000,
}) as CauHinhNguyCo;

/** Cấu hình từ D1 (JSON) -> hợp lệ thì dùng, sai thì null (người gọi dùng mặc định + ghi log). */
export function phanTichCauHinh(json: string | null | undefined): CauHinhNguyCo | null {
  if (!json) return null;
  try {
    const kq = schemaCauHinh.safeParse(JSON.parse(json));
    return kq.success ? kq.data : null;
  } catch {
    return null;
  }
}

export function diemSuKien(cfg: CauHinhNguyCo, loai: string): number {
  return cfg.diem[loai] ?? 0;
}

export function congDiem(cfg: CauHinhNguyCo, diem: number, them: number): number {
  return Math.max(0, Math.min(cfg.diemToiDa, diem + them));
}

export function trangThaiTuDiem(cfg: CauHinhNguyCo, diem: number): TrangThai {
  if (diem >= cfg.nguong.banned) return 'banned';
  if (diem >= cfg.nguong.restricted) return 'restricted';
  if (diem >= cfg.nguong.suspicious) return 'suspicious';
  return 'clean';
}

export function nangHon(a: TrangThai, b: TrangThai): TrangThai {
  return TRANG_THAI.indexOf(a) >= TRANG_THAI.indexOf(b) ? a : b;
}

/** Hành động enforcement trên thiết bị -> trạng thái tối thiểu nó áp. */
export function trangThaiTuThucThi(hanhDong: string): TrangThai {
  if (hanhDong === 'ban') return 'banned';
  if (hanhDong === 'restrict') return 'restricted';
  return 'clean';
}

/** Trạng thái hiệu lực = nặng nhất giữa điểm và các enforcement thiết bị còn hiệu lực. */
export function trangThaiHieuLuc(cfg: CauHinhNguyCo, diem: number, hanhDongDangApDung: readonly string[]): TrangThai {
  return hanhDongDangApDung.reduce<TrangThai>((tt, h) => nangHon(tt, trangThaiTuThucThi(h)), trangThaiTuDiem(cfg, diem));
}

/**
 * Hồi phục uy tín: mỗi tuần trọn vẹn không vi phạm (tính từ mốc muộn hơn giữa vi phạm cuối và lần trừ cuối) trừ
 * `diemMoiTuan`, không xuống dưới sàn. Trả null khi chưa tới lúc trừ.
 */
export function hoiPhuc(
  cfg: CauHinhNguyCo,
  t: { diem: number; viPhamCuoi: number | null; truCuoi: number | null; lanDau: number },
  bayGio: number,
): { diem: number; truLuc: number } | null {
  const { diemMoiTuan, san } = cfg.hoiPhuc;
  if (diemMoiTuan === 0 || t.diem <= san) return null;
  const moc = Math.max(t.viPhamCuoi ?? t.lanDau, t.truCuoi ?? t.lanDau);
  const soTuan = Math.floor((bayGio - moc) / TUAN_MS);
  if (soTuan < 1) return null;
  return { diem: Math.max(san, t.diem - soTuan * diemMoiTuan), truLuc: moc + soTuan * TUAN_MS };
}

/** TTL theo số lần đã bị chặn trước đó (không tính lần bị thu hồi do khiếu nại): 24h -> 7d -> 30d -> 365d. */
export function ttlLeoThang(cfg: CauHinhNguyCo, soLanTruoc: number): { bac: number; ttlMs: number } {
  const bac = Math.min(Math.max(0, soLanTruoc), cfg.ttlBac.length - 1);
  return { bac, ttlMs: cfg.ttlBac[bac] as number };
}
