// S7c2 - phần thuần của trang Báo cáo + Cấu hình từ xa (có test): khoảng ngày giờ VN, so sánh đề xuất với gói đang phục vụ,
// kiểm hợp lệ phía giao diện (server kiểm lại - đây chỉ để báo sớm).
import type { DeXuatApp, DeXuatWeb } from '../api';

const LECH_VN_MS = 7 * 3_600_000;
const NGAY_MS = 86_400_000;

/** "YYYY-MM-DD" (ngày VN) -> ms đầu ngày đó theo giờ VN. */
export function dauNgayVn(ngay: string): number | null {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(ngay)) return null;
  const t = Date.parse(`${ngay}T00:00:00Z`);
  return Number.isNaN(t) ? null : t - LECH_VN_MS;
}

/** ms -> ngày VN "YYYY-MM-DD" (giá trị ô <input type=date>). */
export function ngayVn(ms: number): string {
  return new Date(ms + LECH_VN_MS).toISOString().slice(0, 10);
}

/** Ô "từ ngày" + "đến hết ngày" -> khoảng [tu, den) ms; sai / quá 92 ngày -> null. */
export function khoangTuO(tu: string, den: string): { tu: number; den: number } | null {
  const a = dauNgayVn(tu);
  const b = dauNgayVn(den);
  if (a === null || b === null) return null;
  const k = { tu: a, den: b + NGAY_MS };
  return k.den > k.tu && k.den - k.tu <= 92 * NGAY_MS ? k : null;
}

/** Khoảng N ngày gần nhất tính theo ngày VN (gồm hôm nay). */
export function khoangGanNhat(soNgay: number, bayGio: number): { tu: string; den: string } {
  return { tu: ngayVn(bayGio - (soNgay - 1) * NGAY_MS), den: ngayVn(bayGio) };
}

export type DongKhac = { truong: string; cu: string; moi: string };

const ds = (x: readonly string[]) => [...x].sort().join(', ') || '-';

/** Các trường đề xuất khác gói hiện tại (bỏ qua `ngay` - gói mới luôn có hạn mới). */
export function khacBietApp(cu: DeXuatApp, moi: DeXuatApp, tenPin: (p: string) => string): DongKhac[] {
  const kq: DongKhac[] = [];
  if (cu.toiThieu !== moi.toiThieu) kq.push({ truong: 'toiThieu', cu: String(cu.toiThieu), moi: String(moi.toiThieu) });
  if (cu.khuyenNghi !== moi.khuyenNghi) kq.push({ truong: 'khuyenNghi', cu: String(cu.khuyenNghi), moi: String(moi.khuyenNghi) });
  if (ds(cu.tat) !== ds(moi.tat)) kq.push({ truong: 'tat', cu: ds(cu.tat), moi: ds(moi.tat) });
  if (ds(cu.pin) !== ds(moi.pin)) kq.push({ truong: 'pin', cu: ds(cu.pin.map(tenPin)), moi: ds(moi.pin.map(tenPin)) });
  return kq;
}

export function khacBietWeb(cu: DeXuatWeb, moi: DeXuatWeb): DongKhac[] {
  const kq: DongKhac[] = [];
  if (cu.landing !== moi.landing) kq.push({ truong: 'landing', cu: cu.landing, moi: moi.landing });
  if (cu.admin !== moi.admin) kq.push({ truong: 'admin', cu: cu.admin, moi: moi.admin });
  return kq;
}

/** Như `kiemDeXuatApp` của Worker (phần không cần gói hiện tại). Trả mã lỗi (khớp t.loiMa) hoặc null. */
export function loiDeXuatApp(dx: DeXuatApp, banMoi: number | null): string | null {
  if (!Number.isInteger(dx.toiThieu) || dx.toiThieu < 1 || !Number.isInteger(dx.khuyenNghi)) return 'khuyen-nghi-thap';
  if (dx.khuyenNghi < dx.toiThieu) return 'khuyen-nghi-thap';
  if (banMoi !== null && dx.toiThieu > banMoi) return 'toi-thieu-vuot-ban-moi';
  if (new Set(dx.pin).size < 2) return 'pin-it';
  return null;
}

/** Thanh tỉ lệ cho biểu đồ cột ngang trong trang báo cáo (0..100, tối thiểu 1 khi n > 0 để vẫn thấy). */
export function tiLe(n: number, max: number): number {
  if (n <= 0 || max <= 0) return 0;
  return Math.max(1, Math.round((n / max) * 100));
}
