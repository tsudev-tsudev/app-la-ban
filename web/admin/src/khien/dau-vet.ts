// Thuỷ vân SOC (SH-04) - phần thuần: mã dấu vết + bố cục chấm ẩn + độ đậm theo mức.
// Mã dấu vết = 8 hex đầu SHA-256("soc|email|giờ"): ảnh chụp màn hình lọt ra ngoài -> đọc mã (chữ nhỏ hoặc lưới chấm ẩn khi
// tăng tương phản) -> dò ngược qua danh sách quản trị viên x khung giờ. Không chứa bí mật; chỉ để truy vết, không xác thực.

export type MucThuyVan = 'nhe' | 'chuan';

/** Ô lặp của lớp thuỷ vân (px CSS). Thưa để không phủ dày lên bảng / chữ. */
export const O_THUY_VAN = { rong: 440, cao: 260 } as const;

/** Lưới chấm ẩn 6 x 6 = 32 bit mã + 4 bit chẵn lẻ (mỗi byte một bit). */
export const LUOI_CHAM = 6;

const GIO = 3_600_000;

function hex(b: ArrayBuffer): string {
  return [...new Uint8Array(b)].map((x) => x.toString(16).padStart(2, '0')).join('');
}

export async function maDauVet(email: string, luc: number): Promise<string> {
  const vao = new TextEncoder().encode(`soc|${email.trim().toLowerCase()}|${Math.floor(luc / GIO)}`);
  return hex(await crypto.subtle.digest('SHA-256', vao)).slice(0, 8);
}

/** 8 hex -> 36 bit (32 bit mã theo thứ tự byte, bit cao trước, + 4 bit chẵn lẻ của từng byte). */
export function bitDauVet(ma: string): number[] {
  if (!/^[0-9a-f]{8}$/.test(ma)) return [];
  const bit: number[] = [];
  const chanLe: number[] = [];
  for (let i = 0; i < 4; i++) {
    const b = parseInt(ma.slice(i * 2, i * 2 + 2), 16);
    let p = 0;
    for (let k = 7; k >= 0; k--) {
      const x = (b >> k) & 1;
      bit.push(x);
      p ^= x;
    }
    chanLe.push(p);
  }
  return [...bit, ...chanLe];
}

/**
 * Độ mờ của CẢ lớp (ô vẽ sẵn ở alpha gốc 0.2): nhẹ ~5 %, chuẩn ~9 %; tăng cường (rời cửa sổ, ẩn tab - thường là lúc công cụ
 * chụp màn hình mở) ~18 %. Không có mức 0: thuỷ vân là kiểm soát bảo mật, người xem chỉ chọn độ đậm.
 */
export function doMoLop(muc: MucThuyVan, tangCuong: boolean): number {
  if (tangCuong) return 0.9;
  return muc === 'chuan' ? 0.45 : 0.25;
}

export const ALPHA_GOC = 0.2;

export function nhanThuyVan(email: string, luc: number, ma: string): string {
  const d = new Date(luc + 7 * GIO);
  const hai = (n: number) => String(n).padStart(2, '0');
  return `${email.trim().slice(0, 120)} · ${d.getUTCFullYear()}-${hai(d.getUTCMonth() + 1)}-${hai(d.getUTCDate())} ${hai(d.getUTCHours())}:${hai(d.getUTCMinutes())} · #${ma}`;
}

export function laMucThuyVan(s: unknown): s is MucThuyVan {
  return s === 'nhe' || s === 'chuan';
}
