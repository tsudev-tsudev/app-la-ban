// R3c (QUYET_DINH Q52): nonce + bộ đếm giới hạn tốc độ trên D1 (migration 0011). Hàm chỉ SINH câu lệnh tham số hoá
// và QUYẾT ĐỊNH từ dòng trả về - phần chạy ở mw/dich-vu.ts (goiNonce) và mw/gioi-han.ts (gioiHanRoute).
import type { CauLenh } from './don-dep';
import { uocLuong } from './gioi-han';

/** Nonce yêu cầu: chèn mới, hoặc ghi đè dòng ĐÃ hết hạn; changes = 0 nghĩa là nonce còn hạn đã dùng -> phát lại. */
export function cauNonce(phamVi: string, nonce: string, bayGio: number, ttlMs: number): CauLenh {
  return {
    sql:
      "INSERT INTO nonce_dung (pham_vi, loai, nonce, het_han) VALUES (?, 'n', ?, ?) " +
      'ON CONFLICT (pham_vi, loai, nonce) DO UPDATE SET het_han = excluded.het_han WHERE nonce_dung.het_han <= ?',
    thamSo: [phamVi, nonce, bayGio + ttlMs, bayGio],
  };
}

/** Thách thức server cấp (S2): ngẫu nhiên 32 byte nên không trùng; ghi đè để lệnh luôn thành công. */
export function cauCapThach(phamVi: string, nonce: string, bayGio: number, ttlMs: number): CauLenh {
  return {
    sql: "INSERT OR REPLACE INTO nonce_dung (pham_vi, loai, nonce, het_han) VALUES (?, 'c', ?, ?)",
    thamSo: [phamVi, nonce, bayGio + ttlMs],
  };
}

/** Dùng thách thức: xoá + trả hạn (RETURNING) -> hợp lệ nếu có dòng và còn hạn. Xoá cả khi hết hạn (dùng một lần). */
export function cauDungThach(phamVi: string, nonce: string): CauLenh {
  return {
    sql: "DELETE FROM nonce_dung WHERE pham_vi = ? AND loai = 'c' AND nonce = ? RETURNING het_han",
    thamSo: [phamVi, nonce],
  };
}

export const thachConHan = (dong: { het_han: number } | null | undefined, bayGio: number): boolean =>
  !!dong && dong.het_han > bayGio;

export type DongDem = { bat_dau: number; dem: number; dem_truoc: number };

/**
 * Đếm một yêu cầu cho [khoa] (cửa sổ cố định căn theo bội số [cuaSoMs]) và trả trạng thái mới (RETURNING). SQLite tính
 * mọi biểu thức SET từ dòng CŨ: cùng cửa sổ -> dem + 1; cửa sổ ngay trước -> dem_truoc = dem, dem = 1; xa hơn -> làm lại.
 * Khác DO GioiHanToc: yêu cầu bị từ chối CŨNG được đếm (dội liên tục thì bị chặn tiếp - chặt hơn, không lỏng hơn).
 */
export function cauDem(khoa: string, bayGio: number, cuaSoMs: number): CauLenh {
  const batDau = bayGio - (bayGio % cuaSoMs);
  return {
    sql:
      'INSERT INTO gioi_han_dem (khoa, bat_dau, dem, dem_truoc, het_han) VALUES (?1, ?2, 1, 0, ?2 + 2 * ?3) ' +
      'ON CONFLICT (khoa) DO UPDATE SET ' +
      'dem_truoc = CASE WHEN gioi_han_dem.bat_dau = ?2 THEN gioi_han_dem.dem_truoc WHEN gioi_han_dem.bat_dau = ?2 - ?3 THEN gioi_han_dem.dem ELSE 0 END, ' +
      'dem = CASE WHEN gioi_han_dem.bat_dau = ?2 THEN gioi_han_dem.dem + 1 ELSE 1 END, ' +
      'bat_dau = ?2, het_han = ?2 + 2 * ?3 ' +
      'RETURNING bat_dau, dem, dem_truoc',
    thamSo: [khoa, batDau, cuaSoMs],
  };
}

export type QuyetDinhDem = { choPhep: boolean; thuLaiSau: number; lanDauVuot: boolean };

/**
 * Từ trạng thái SAU khi đếm (đã gồm yêu cầu này): ước lượng > giới hạn -> từ chối. [lanDauVuot] = yêu cầu này là lần đầu
 * vượt (ước lượng trước nó còn trong giới hạn) -> báo RATE_ABUSE một lần mỗi đợt.
 */
export function quyetDinhDem(d: DongDem, bayGio: number, gioiHan: number, cuaSoMs: number): QuyetDinhDem {
  const sau = uocLuong({ batDau: d.bat_dau, dem: d.dem, demTruoc: d.dem_truoc }, bayGio, cuaSoMs);
  if (sau <= gioiHan) return { choPhep: true, thuLaiSau: 0, lanDauVuot: false };
  const ketThuc = d.bat_dau + cuaSoMs;
  let cho = ketThuc - bayGio;
  // Còn chỗ trong cửa sổ hiện tại -> chỉ cần chờ phần trọng số của cửa sổ trước giảm đủ.
  if (d.dem_truoc > 0 && d.dem <= gioiHan) cho = Math.max(0, d.bat_dau + (1 - (gioiHan - d.dem) / d.dem_truoc) * cuaSoMs - bayGio);
  return { choPhep: false, thuLaiSau: Math.max(1, Math.ceil(cho / 1000)), lanDauVuot: sau - 1 <= gioiHan };
}

/** Dọn bảng tạm (cron 5 phút): nonce / thách thức / bộ đếm hết hạn. */
export function cauDonDem(bayGio: number): CauLenh[] {
  return [
    { sql: 'DELETE FROM nonce_dung WHERE het_han <= ?', thamSo: [bayGio] },
    { sql: 'DELETE FROM gioi_han_dem WHERE het_han <= ?', thamSo: [bayGio] },
  ];
}
