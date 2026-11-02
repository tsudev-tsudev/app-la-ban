// R3c - đo độ trễ từng bước trong một yêu cầu, ghi vào Analytics Engine cùng điểm dữ liệu tổng (mw/co-ban.ts).
// `Date.now()` trong Worker chỉ nhảy khi có I/O (chống đo thời gian kênh phụ) -> số đo được ĐÚNG LÀ thời gian chờ I/O
// (D1, DO, KV, R2, fetch), CPU thuần không hiện ra. Bước chạy song song thì mỗi bước tự tính -> tổng các bước có thể
// lớn hơn `tong`.

/** Thứ tự cố định = vị trí doubles trong AE (double1 là tổng, giữ nguyên từ S1 để truy vấn cũ không đổi nghĩa). */
export const BUOC_DO = [
  /** D1 danh sách chặn IP / dải / ASN (mw/chan.ts) - 0 khi trúng đệm isolate. */
  'chan',
  /** Rate Limiting binding theo IP (mw/gioi-han.ts gioiHanThoIp). */
  'rlIp',
  /** D1 phiên + thiết bị (mw/xac-thuc.ts). */
  'phien',
  /** DO KhoNonce (chống phát lại, thách thức). */
  'nonce',
  /** DO GioiHanToc theo route. */
  'gioiHan',
  /** KV / R2 của handler (Remote Config, latest.json). */
  'luuTru',
  /** D1 của handler (idempotency, Threat Engine, ghi). */
  'd1',
] as const;
export type BuocDo = (typeof BUOC_DO)[number];

export class DongHo {
  private readonly ms = new Map<BuocDo, number>();

  cong(buoc: BuocDo, ms: number): void {
    this.ms.set(buoc, (this.ms.get(buoc) ?? 0) + Math.max(0, ms));
  }

  lay(buoc: BuocDo): number {
    return this.ms.get(buoc) ?? 0;
  }

  /** doubles AE: [tong, ...BUOC_DO, lanh] - `lanh` = 1 nếu là yêu cầu đầu tiên của isolate (đệm trống). */
  doubles(tong: number, lanh: boolean): number[] {
    return [Math.max(0, tong), ...BUOC_DO.map((b) => this.lay(b)), lanh ? 1 : 0];
  }
}

/** Chờ `viec` và cộng thời gian chờ vào `buoc` (kể cả khi lỗi). Không có đồng hồ (test, cron) -> chỉ chờ. */
export async function doBuoc<T>(dh: DongHo | undefined, buoc: BuocDo, viec: () => Promise<T>, bayGio: () => number = Date.now): Promise<T> {
  if (!dh) return viec();
  const t0 = bayGio();
  try {
    return await viec();
  } finally {
    dh.cong(buoc, bayGio() - t0);
  }
}

/** Đường dẫn KHÔNG chạm D1 / DO ở middleware chung (health cho trang trạng thái + máy đo; robots). Allow-list tĩnh. */
export const DUONG_KHONG_KIEM_CHAN: ReadonlySet<string> = new Set(['/v1/health', '/robots.txt']);
