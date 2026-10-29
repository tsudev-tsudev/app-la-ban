// SH-04: nội dung watermark động của admin - email người xem + thời điểm (giờ Việt Nam, đổi mỗi phút) để ảnh chụp màn hình
// lộ ra ngoài truy được người chụp.

function hai(n: number): string {
  return String(n).padStart(2, '0');
}

/** "email · 2026-10-29 19:05 (UTC+7)" - tính giờ UTC+7 thủ công, không phụ thuộc múi giờ máy người xem. */
export function noiDungWatermark(email: string, thoiDiem: number): string {
  const d = new Date(thoiDiem + 7 * 3_600_000);
  const ngay = `${d.getUTCFullYear()}-${hai(d.getUTCMonth() + 1)}-${hai(d.getUTCDate())}`;
  const gio = `${hai(d.getUTCHours())}:${hai(d.getUTCMinutes())}`;
  return `${email.trim().slice(0, 120)} · ${ngay} ${gio} (UTC+7)`;
}

/** Số ô lặp theo lưới để phủ kín vùng [rong] x [cao] (ô cỡ [oRong] x [oCao]), có trần để không tạo quá nhiều nút DOM. */
export function soO(rong: number, cao: number, oRong = 320, oCao = 140, toiDa = 120): number {
  if (rong <= 0 || cao <= 0) return 0;
  return Math.min(toiDa, Math.ceil(rong / oRong) * Math.ceil(cao / oCao));
}
