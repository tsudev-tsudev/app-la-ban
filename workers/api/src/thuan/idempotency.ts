// SEC-API API-03: Idempotency-Key cho POST. Cùng khoá + cùng nội dung -> phát lại phản hồi đã lưu;
// cùng khoá + nội dung khác -> 422; khoá đang được xử lý ở yêu cầu khác -> 409.
import { jsonChuan, sha256Hex } from './bam';

/** Khoá giữ 24 giờ (đủ cho app thử lại khi mất mạng). */
export const IDEM_THOI_HAN_MS = 24 * 60 * 60 * 1000;
/** Bản ghi `dang` quá thời gian này coi như yêu cầu trước đã chết -> cho làm lại. */
export const IDEM_DANG_TOI_DA_MS = 60 * 1000;

export type BanGhiIdem = {
  bam_yeu_cau: string;
  trang_thai: 'dang' | 'xong';
  ma_http: number | null;
  noi_dung: string | null;
  loai_noi_dung: string | null;
  tao_luc: number;
  het_han: number;
};

export type QuyetDinhIdem =
  | { loai: 'moi' }
  | { loai: 'phat-lai'; ma: number; noiDung: string; loaiNoiDung: string }
  | { loai: 'khac-noi-dung' }
  | { loai: 'dang-xu-ly' };

/** Băm (phương thức, đường dẫn, body chuẩn hoá) - body JSON khác thứ tự khoá vẫn cùng băm. */
export async function bamYeuCau(phuongThuc: string, duongDan: string, body: unknown): Promise<string> {
  return sha256Hex(`${phuongThuc.toUpperCase()} ${duongDan}\n${jsonChuan(body)}`);
}

export function quyetDinhIdem(banGhi: BanGhiIdem | null, bam: string, bayGio: number): QuyetDinhIdem {
  if (!banGhi || banGhi.het_han <= bayGio) return { loai: 'moi' };
  if (banGhi.bam_yeu_cau !== bam) return { loai: 'khac-noi-dung' };
  if (banGhi.trang_thai === 'dang') {
    return bayGio - banGhi.tao_luc > IDEM_DANG_TOI_DA_MS ? { loai: 'moi' } : { loai: 'dang-xu-ly' };
  }
  return {
    loai: 'phat-lai',
    ma: banGhi.ma_http ?? 200,
    noiDung: banGhi.noi_dung ?? '',
    loaiNoiDung: banGhi.loai_noi_dung ?? 'application/json',
  };
}

/** Chỉ lưu phản hồi để phát lại khi đã xử lý xong có kết quả xác định (2xx / 4xx trừ 408, 425, 429). */
export function nenLuuPhanHoi(ma: number): boolean {
  if (ma >= 500) return false;
  return ![408, 425, 429].includes(ma);
}
